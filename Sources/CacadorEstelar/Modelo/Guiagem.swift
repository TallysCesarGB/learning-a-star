import SwiftUI

// Guiagem do caçador no modo Perseguição.
//
// A Gulosa e o A* respondem "qual é a rota até o ponto X?" (planejamento).
// A guiagem responde "qual deve ser o ponto X?" e "quando vale recalcular?".
//
// A navegação proporcional (PN) vem da guiagem de mísseis. Ela usa o
// Zero-Effort Miss (ZEM): o erro de passagem que vai acontecer se ninguém
// mudar de rumo a partir de agora. O comando de correção é
//
//     a = N · ZEM / t_go²
//
// onde N é o ganho de navegação e t_go é o tempo que falta até o encontro.
// Na grade, "corrigir a rota" é rodar uma nova busca, então o caçador só
// replaneja quando esse comando passa de um limiar. É uma malha fechada: a cada
// salto ele mede o alvo, atualiza a estimativa de velocidade e recalcula o ZEM.

// MARK: - Tipos de guiagem

enum Guiagem: String, CaseIterable, Identifiable {
    case pura = "Pura"
    case zem = "PN · ZEM"
    case antecipada = "PN + antecipação"

    var id: String { rawValue }

    var nomeCompleto: String {
        switch self {
        case .pura:       return "Perseguição pura"
        case .zem:        return "Navegação proporcional por ZEM"
        case .antecipada: return "Navegação proporcional com antecipação"
        }
    }

    var simbolo: String {
        switch self {
        case .pura:       return "arrow.right.circle"
        case .zem:        return "location.circle"
        case .antecipada: return "arrow.up.forward.circle"
        }
    }

    var descricao: String {
        switch self {
        case .pura:
            return "Mira na posição atual do mensageiro e replaneja toda vez que ele se move."
        case .zem:
            return "Mira no mensageiro, mas só replaneja quando o comando N·ZEM/t_go² passa do limiar."
        case .antecipada:
            return "Igual à PN por ZEM, mas mira no ponto de interceptação previsto."
        }
    }

    var cor: Color {
        switch self {
        case .pura:       return Color(nsColor: Paleta.ouro)
        case .zem:        return Color(nsColor: Paleta.magenta)
        case .antecipada: return Color(nsColor: Paleta.violeta)
        }
    }

    /// As duas variantes de PN usam o ZEM para decidir quando replanejar.
    var usaZEM: Bool { self != .pura }
}

enum ParametrosPN {
    /// Ganho de navegação N. Na literatura de guiagem, fica entre 3 e 5.
    static let ganho = 3.0
    /// Valor do comando a partir do qual vale pagar uma nova busca.
    static let limiar = 0.1
    /// Constante de tempo do filtro de velocidade, em unidades de custo.
    static let tau = 12.0
}

// MARK: - Vetor 2D (linha, coluna) em números reais

struct Vetor: Equatable {
    var r: Double
    var c: Double

    static let zero = Vetor(r: 0, c: 0)

    init(r: Double, c: Double) {
        self.r = r
        self.c = c
    }

    init(_ p: Pos) {
        r = Double(p.r)
        c = Double(p.c)
    }

    var norma: Double { (r * r + c * c).squareRoot() }

    static func + (a: Vetor, b: Vetor) -> Vetor { Vetor(r: a.r + b.r, c: a.c + b.c) }
    static func - (a: Vetor, b: Vetor) -> Vetor { Vetor(r: a.r - b.r, c: a.c - b.c) }
    static func * (a: Vetor, k: Double) -> Vetor { Vetor(r: a.r * k, c: a.c * k) }
}

// MARK: - Observador de velocidade (a retroalimentação)

/// Estima a velocidade do mensageiro em células por unidade de custo.
/// É um filtro passa-baixa de 1ª ordem: a cada medida, a estimativa anda uma
/// fração α do erro entre o que foi medido e o que se esperava.
struct EstimadorAlvo {
    private(set) var velocidade = Vetor.zero
    private var ultima: Pos
    private var ultimoTempo = 0.0

    init(presa: Pos) {
        ultima = presa
    }

    mutating func observar(_ presa: Pos, tempo: Double) {
        let dt = tempo - ultimoTempo
        guard dt > 0 else { return }
        let medida = (Vetor(presa) - Vetor(ultima)) * (1 / dt)
        let alfa = 1 - exp(-dt / ParametrosPN.tau)
        velocidade = velocidade + (medida - velocidade) * alfa
        ultima = presa
        ultimoTempo = tempo
    }
}

// MARK: - Navegação proporcional

struct LeituraZEM {
    /// Distância, em células, entre onde o alvo vai estar e onde a rota termina.
    let zem: Double
    /// Custo que falta percorrer na rota atual (o "tempo" até o encontro).
    let tgo: Double
    /// N · ZEM / t_go²
    let comando: Double
    /// Célula onde o alvo deve estar quando a rota terminar.
    let previsto: Pos
}

enum NavegacaoProporcional {

    /// Projeta o alvo no futuro supondo velocidade constante.
    static func prever(_ grade: Grade, presa: Pos, estimador: EstimadorAlvo, tgo: Double) -> Vetor {
        let p = Vetor(presa) + estimador.velocidade * tgo
        return Vetor(r: min(max(p.r, 0), Double(grade.linhas - 1)),
                     c: min(max(p.c, 0), Double(grade.colunas - 1)))
    }

    /// Distância que o caçador anda na grade: Manhattan (4 direções) ou octil (8).
    static func distanciaGrade(_ a: Vetor, _ b: Vetor, diagonal: Bool) -> Double {
        let dr = abs(a.r - b.r)
        let dc = abs(a.c - b.c)
        return diagonal ? max(dr, dc) + (2.0.squareRoot() - 1) * min(dr, dc) : dr + dc
    }

    /// Célula passável mais próxima de um ponto real (busca em anéis de raio 0 a 3).
    static func celulaLivre(_ grade: Grade, perto ponto: Vetor, reserva: Pos) -> Pos {
        let r0 = Int(ponto.r.rounded(.toNearestOrEven))
        let c0 = Int(ponto.c.rounded(.toNearestOrEven))
        for raio in 0...3 {
            var melhor: Pos?
            var menor = Double.infinity
            for dr in -raio...raio {
                for dc in -raio...raio where max(abs(dr), abs(dc)) == raio {
                    let q = Pos(r: r0 + dr, c: c0 + dc)
                    guard grade.contem(q), grade[q].passavel else { continue }
                    let d = (Vetor(q) - ponto).norma
                    if d < menor {
                        melhor = q
                        menor = d
                    }
                }
            }
            if let melhor { return melhor }
        }
        return reserva
    }

    /// Ponto de interceptação previsto. O t_go depende do ponto, e o ponto depende
    /// do t_go, então a conta é refeita duas vezes (iteração de ponto fixo).
    static func calcularMira(_ grade: Grade, predador: Pos, presa: Pos, estimador: EstimadorAlvo,
                             custoMedio: Double, diagonal: Bool) -> Pos {
        let origem = Vetor(predador)
        var tgo = distanciaGrade(origem, Vetor(presa), diagonal: diagonal) * custoMedio
        var ponto = prever(grade, presa: presa, estimador: estimador, tgo: tgo)
        tgo = distanciaGrade(origem, ponto, diagonal: diagonal) * custoMedio
        ponto = prever(grade, presa: presa, estimador: estimador, tgo: tgo)
        return celulaLivre(grade, perto: ponto, reserva: presa)
    }

    /// Mede o ZEM da rota atual e o comando de correção.
    static func medir(_ grade: Grade, presa: Pos, estimador: EstimadorAlvo,
                      destino: Pos, custoRestante: Double) -> LeituraZEM {
        let tgo = custoRestante
        let previsto = prever(grade, presa: presa, estimador: estimador, tgo: tgo)
        let zem = (previsto - Vetor(destino)).norma
        let comando = ParametrosPN.ganho * zem / pow(max(tgo, 1), 2)
        return LeituraZEM(zem: zem, tgo: tgo, comando: comando,
                          previsto: Pos(r: Int(previsto.r.rounded()), c: Int(previsto.c.rounded())))
    }

    static func custoRestante(_ grade: Grade, _ caminho: [Pos]) -> Double {
        guard caminho.count > 1 else { return 0 }
        var total = 0.0
        for k in 0..<(caminho.count - 1) {
            total += grade.custoPasso(de: caminho[k], para: caminho[k + 1])
        }
        return total
    }
}

// MARK: - Fuga do mensageiro (compartilhada pelo jogo e pelo simulador)

enum Fuga {
    /// O mensageiro anda uma célula a cada 4 unidades de custo gastas pelo caçador.
    static let custoPorSalto = 4.0

    static func proximaPosicao<R: RandomNumberGenerator>(_ grade: Grade, presa: Pos, predador: Pos,
                                                        rng: inout R) -> Pos {
        let opcoes = grade.vizinhos(de: presa, diagonal: false).map { $0.pos }
        guard !opcoes.isEmpty else { return presa }
        func distancia(_ p: Pos) -> Int { abs(p.r - predador.r) + abs(p.c - predador.c) }
        if Double.random(in: 0..<1, using: &rng) < 0.75 {
            // Foge maximizando a distância; no empate prefere setor barato.
            return opcoes.max { a, b in
                let da = distancia(a), db = distancia(b)
                return da == db ? grade[a].custo > grade[b].custo : da < db
            }!
        }
        return opcoes.randomElement(using: &rng)!
    }
}

/// Gerador SplitMix64 com semente: as três guiagens enfrentam o mesmo "sorteio" de fuga.
struct GeradorSemente: RandomNumberGenerator {
    private var estado: UInt64

    init(semente: UInt64) {
        estado = semente
    }

    mutating func next() -> UInt64 {
        estado &+= 0x9E37_79B9_7F4A_7C15
        var z = estado
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Simulador sem animação (para o comparativo)

struct ResultadoPerseguicao {
    let capturou: Bool
    let custo: Double
    let passos: Int
    let replanejamentos: Int
    let nos: Int
    let tempoMs: Double
}

/// Mesma lógica do modo Perseguição do JogoModel, sem animação e sem esperas.
enum SimuladorPerseguicao {
    static let limitePassos = 1500

    static func rodar(_ grade: Grade, inicio: Pos, alvo: Pos, algoritmo: Algoritmo,
                      heuristica: Heuristica, diagonal: Bool, guiagem: Guiagem,
                      semente: UInt64) -> ResultadoPerseguicao {
        var rng = GeradorSemente(semente: semente)
        var predador = inicio
        var presa = alvo
        var custo = 0.0
        var passos = 0
        var replanejamentos = 0
        var nos = 0
        var tempoMs = 0.0
        var orcamento = 0.0
        var estimador = EstimadorAlvo(presa: presa)
        var primeira = true

        func resultado(_ capturou: Bool) -> ResultadoPerseguicao {
            ResultadoPerseguicao(capturou: capturou, custo: custo, passos: passos,
                                 replanejamentos: replanejamentos, nos: nos, tempoMs: tempoMs)
        }

        while true {
            var destino = presa
            if guiagem == .antecipada && !primeira {
                let custoMedio = passos > 0 ? custo / Double(passos) : 2
                destino = NavegacaoProporcional.calcularMira(grade, predador: predador, presa: presa,
                                                            estimador: estimador, custoMedio: custoMedio,
                                                            diagonal: diagonal)
            }
            var r = Buscador.buscar(grade, de: predador, ate: destino, algoritmo: algoritmo,
                                    heuristica: heuristica, diagonal: diagonal)
            nos += r.nosExplorados
            tempoMs += r.tempoMs
            if !r.encontrou && destino != presa {
                // Mira prevista sem rota (bolsão fechado): volta a mirar no alvo.
                r = Buscador.buscar(grade, de: predador, ate: presa, algoritmo: algoritmo,
                                    heuristica: heuristica, diagonal: diagonal)
                nos += r.nosExplorados
                tempoMs += r.tempoMs
            }
            guard r.encontrou else { return resultado(false) }
            primeira = false

            var caminho = r.caminho
            var restante = r.custo
            caminhada: while caminho.count > 1 {
                let passo = grade.custoPasso(de: caminho[0], para: caminho[1])
                caminho.removeFirst()
                restante -= passo
                predador = caminho[0]
                custo += passo
                passos += 1
                if predador == presa { return resultado(true) }
                if passos >= limitePassos { return resultado(false) }

                orcamento += passo
                var moveu = false
                while orcamento >= Fuga.custoPorSalto {
                    orcamento -= Fuga.custoPorSalto
                    presa = Fuga.proximaPosicao(grade, presa: presa, predador: predador, rng: &rng)
                    moveu = true
                    if presa == predador { return resultado(true) }
                }
                estimador.observar(presa, tempo: custo)

                if guiagem == .pura {
                    if moveu { break caminhada }
                } else if caminho.count > 1 {
                    let leitura = NavegacaoProporcional.medir(grade, presa: presa, estimador: estimador,
                                                              destino: caminho[caminho.count - 1],
                                                              custoRestante: restante)
                    if leitura.comando > ParametrosPN.limiar { break caminhada }
                }
            }
            replanejamentos += 1
        }
    }
}

// MARK: - Comparativo das três guiagens

struct ComparativoGuiagem {
    struct Resumo {
        let taxaCaptura: Double
        let custo: Double
        let passos: Double
        let replanejamentos: Double
        let nos: Double
        let tempoMs: Double
    }

    let rodadas: Int
    let configuracao: String
    let resumos: [Guiagem: Resumo]

    /// Roda as três guiagens no setor atual, com as mesmas sementes de fuga.
    /// As médias consideram só as rodadas em que houve captura.
    static func calcular(_ grade: Grade, inicio: Pos, alvo: Pos, algoritmo: Algoritmo,
                         heuristica: Heuristica, diagonal: Bool, rodadas: Int) -> ComparativoGuiagem {
        var resumos: [Guiagem: Resumo] = [:]
        for guiagem in Guiagem.allCases {
            let resultados = (0..<rodadas).map { s in
                SimuladorPerseguicao.rodar(grade, inicio: inicio, alvo: alvo, algoritmo: algoritmo,
                                           heuristica: heuristica, diagonal: diagonal,
                                           guiagem: guiagem, semente: UInt64(7 + s))
            }
            let capturas = resultados.filter { $0.capturou }
            func media(_ valor: (ResultadoPerseguicao) -> Double) -> Double {
                capturas.isEmpty ? 0 : capturas.map(valor).reduce(0, +) / Double(capturas.count)
            }
            resumos[guiagem] = Resumo(
                taxaCaptura: Double(capturas.count) / Double(max(rodadas, 1)),
                custo: media { $0.custo },
                passos: media { Double($0.passos) },
                replanejamentos: media { Double($0.replanejamentos) },
                nos: media { Double($0.nos) },
                tempoMs: media { $0.tempoMs })
        }
        let config = "\(algoritmo.rawValue), \(heuristica.rawValue), \(diagonal ? "8" : "4") direções"
        return ComparativoGuiagem(rodadas: rodadas, configuracao: config, resumos: resumos)
    }
}