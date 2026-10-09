import SwiftUI
import AppKit

// MARK: - Tipos de apoio

enum ModoJogo: String, CaseIterable, Identifiable {
    case classico = "Interceptação"
    case fuga = "Perseguição"
    case meteoros = "Chuva de meteoros"

    var id: String { rawValue }

    var simbolo: String {
        switch self {
        case .classico: return "scope"
        case .fuga:     return "paperplane.fill"
        case .meteoros: return "burst.fill"
        }
    }

    var descricao: String {
        switch self {
        case .classico:
            return "O mensageiro está parado em B. A rota é comparada com o custo ótimo."
        case .fuga:
            return "O mensageiro foge a cada 4 unidades de custo que o caçador gasta. Rotas caras dão vantagem a ele."
        case .meteoros:
            return "A cada 5 saltos caem meteoros no setor, às vezes sobre a rota, forçando replanejamento."
        }
    }
}

enum ModoCamera: String, CaseIterable, Identifiable {
    case orbital = "Orbital"
    case tatica = "Tática"
    case perseguicao = "Cockpit"

    var id: String { rawValue }

    var simbolo: String {
        switch self {
        case .orbital:     return "rotate.3d"
        case .tatica:      return "square.grid.2x2"
        case .perseguicao: return "airplane"
        }
    }
}

enum Fase: Equatable {
    case parado, explorando, perseguindo, capturou, escapou, semCaminho

    var titulo: String {
        switch self {
        case .parado:      return "Em espera"
        case .explorando:  return "Varredura de sensores"
        case .perseguindo: return "Em perseguição"
        case .capturou:    return "Alvo interceptado"
        case .escapou:     return "O alvo escapou"
        case .semCaminho:  return "Sem rota"
        }
    }

    var simbolo: String {
        switch self {
        case .parado:      return "moon.zzz.fill"
        case .explorando:  return "dot.radiowaves.left.and.right"
        case .perseguindo: return "location.north.fill"
        case .capturou:    return "checkmark.seal.fill"
        case .escapou:     return "wind"
        case .semCaminho:  return "xmark.octagon.fill"
        }
    }

    var cor: Color {
        switch self {
        case .parado:      return Color(nsColor: Paleta.ciano)
        case .explorando:  return Color(nsColor: Paleta.ouro)
        case .perseguindo: return Color(nsColor: Paleta.brasa)
        case .capturou:    return Color(nsColor: Paleta.verde)
        case .escapou:     return Color(nsColor: Paleta.magenta)
        case .semCaminho:  return Color(nsColor: Paleta.brasa)
        }
    }

    var ativa: Bool { self == .explorando || self == .perseguindo }
}

struct Metricas {
    var nosExplorados = 0
    var tempoMs = 0.0
    var custoPlanejado: Double?
    var custoPercorrido = 0.0
    var passos = 0
    var replanejamentos = 0
    var maxFronteira = 0
    var custoOtimo: Double?
    var celulasHostis = 0
    var zem: Double?
    var tgo: Double?

    /// custo ótimo / custo encontrado (1.0 = rota perfeita).
    var eficiencia: Double? {
        guard let o = custoOtimo, let c = custoPlanejado, c > 0, c.isFinite else { return nil }
        return min(1, o / c)
    }
}

struct Duelo {
    let gulosa: ResultadoBusca
    let aEstrela: ResultadoBusca

    var veredito: String {
        let g = gulosa, a = aEstrela
        guard a.encontrou, g.encontrou else { return "Não existe rota entre A e B neste setor." }
        let diferenca = g.nosExplorados - a.nosExplorados
        let textoNos = diferenca < 0
            ? "A Gulosa varreu \(-diferenca) nós a menos."
            : "O A* varreu \(diferenca) nós a menos."
        if g.custo > a.custo + 1e-6 {
            let pct = (g.custo - a.custo) / g.custo * 100
            return String(format: "O A* encontrou uma rota %.0f%% mais barata (%.1f contra %.1f). ", pct, a.custo, g.custo) + textoNos
        } else if a.custo > g.custo + 1e-6 {
            return "A Gulosa venceu no custo: a heurística atual não é admissível, e o A* perdeu a garantia de ótimo. " + textoNos
        } else {
            return "Empate no custo (\(a.custo.fmt1)). " + textoNos
        }
    }
}

struct RegistroCorrida: Identifiable {
    let id = UUID()
    let algoritmo: Algoritmo
    let heuristica: Heuristica
    let modo: String
    let nos: Int
    let tempoMs: Double
    let custo: Double?
    let eficiencia: Double?
    let sucesso: Bool
}

enum Conquista: String, CaseIterable, Identifiable {
    case saltoPerfeito, pilotoSortudo, sensorAfiado, cascoChamuscado,
         cacadorRecompensas, sobrevivente, sabotador, esquadrao

    var id: String { rawValue }

    var simbolo: String {
        switch self {
        case .saltoPerfeito:      return "target"
        case .pilotoSortudo:      return "sparkles"
        case .sensorAfiado:       return "antenna.radiowaves.left.and.right"
        case .cascoChamuscado:    return "flame.fill"
        case .cacadorRecompensas: return "scope"
        case .sobrevivente:       return "shield.fill"
        case .sabotador:          return "hammer.fill"
        case .esquadrao:          return "person.3.fill"
        }
    }

    var titulo: String {
        switch self {
        case .saltoPerfeito:      return "Salto perfeito"
        case .pilotoSortudo:      return "Piloto sortudo"
        case .sensorAfiado:       return "Sensor afiado"
        case .cascoChamuscado:    return "Casco chamuscado"
        case .cacadorRecompensas: return "Caçador de recompensas"
        case .sobrevivente:       return "Sobrevivente"
        case .sabotador:          return "Sabotador"
        case .esquadrao:          return "Esquadrão"
        }
    }

    var descricao: String {
        switch self {
        case .saltoPerfeito:      return "Interceptar com custo ótimo no modo Interceptação."
        case .pilotoSortudo:      return "A Busca Gulosa encontrou a rota ótima."
        case .sensorAfiado:       return "Interceptar varrendo menos de 5% do setor livre."
        case .cascoChamuscado:    return "Atravessar 10 ou mais células de detritos ou tempestade."
        case .cacadorRecompensas: return "Capturar o mensageiro no modo Perseguição."
        case .sobrevivente:       return "Interceptar durante uma chuva de meteoros."
        case .sabotador:          return "Forçar replanejamento alterando o setor durante a caçada."
        case .esquadrao:          return "Colocar Gulosa e A* frente a frente em um duelo."
        }
    }
}

enum Estrelas {
    static func texto(_ e: Double?) -> String {
        guard let e else { return "" }
        if e >= 0.999 { return "★★★" }
        if e >= 0.85 { return "★★☆" }
        if e >= 0.6 { return "★☆☆" }
        return "☆☆☆"
    }
}

enum Som {
    static func tocar(_ nome: String) {
        NSSound(named: NSSound.Name(nome))?.play()
    }
}

// MARK: - Modelo do jogo

@MainActor
final class JogoModel: ObservableObject {

    // Configuração
    @Published var algoritmo: Algoritmo = .aEstrela
    @Published var heuristica: Heuristica = .manhattan
    @Published var diagonal = false
    @Published var modo: ModoJogo = .classico
    @Published var velocidade: Double = 0.55
    @Published var pincel: Terreno = .asteroide
    @Published var tamanhoPincel = 1
    @Published var tipoMapa: TipoMapa = .natureza
    @Published var tamanho: TamanhoGrade = .medio
    @Published var densidade: Double = 0.28
    @Published var camera: ModoCamera = .orbital
    @Published var somAtivo = true
    @Published var guiagem: Guiagem = .zem

    // Mundo
    @Published var grade: Grade
    @Published var inicio: Pos
    @Published var alvo: Pos
    @Published var predador: Pos
    @Published var presa: Pos

    // Visualização
    @Published var explorados = Set<Pos>()
    @Published var fronteira = Set<Pos>()
    @Published var caminho: [Pos] = []
    @Published var rastro: [Pos] = []
    @Published var duelo: Duelo?
    @Published var dueloPasso = 0
    @Published var impactos = 0
    /// Onde a navegação proporcional prevê que o mensageiro estará (marcador 3D).
    @Published var previsto: Pos?
    @Published var comparativo: ComparativoGuiagem?
    @Published var comparando = false

    // Estado e gamificação
    @Published var fase: Fase = .parado
    @Published var metricas = Metricas()
    @Published var mensagem = "Pinte o setor, arraste A (caçador) e B (mensageiro) e inicie a caçada."
    @Published var historico: [RegistroCorrida] = []
    @Published var conquistas = Set<Conquista>()
    @Published var toast: Conquista?

    /// Duração do último salto do caçador; a cena 3D usa para animar o movimento.
    private(set) var duracaoPasso = 0.15

    private var tarefa: Task<Void, Never>?
    private var orcamentoPresa = 0.0
    private var estimador = EstimadorAlvo(presa: Pos(r: 0, c: 0))
    private var gerador = SystemRandomNumberGenerator()
    private var mapaAlterado = false
    private let limitePassos = 1500

    init() {
        let (g, i, a) = JogoModel.montarMundo(tipo: .natureza, tamanho: .medio, densidade: 0.28)
        grade = g
        inicio = i
        alvo = a
        predador = i
        presa = a
    }

    nonisolated static func montarMundo(tipo: TipoMapa, tamanho: TamanhoGrade, densidade: Double) -> (Grade, Pos, Pos) {
        var g = GeradorMapa.gerar(tipo, linhas: tamanho.linhas, colunas: tamanho.colunas, densidade: densidade)
        let i = Pos(r: tamanho.linhas / 2, c: 1)
        let a = Pos(r: tamanho.linhas / 2, c: tamanho.colunas - 2)
        for p in [i, a] {
            for dr in -1...1 {
                for dc in -1...1 {
                    let q = Pos(r: p.r + dr, c: p.c + dc)
                    if g.contem(q), !g[q].passavel { g[q] = .vacuo }
                }
            }
            g[p] = .rota
        }
        return (g, i, a)
    }

    // MARK: Edição do setor

    func gerarMapa() {
        parar()
        let (g, i, a) = Self.montarMundo(tipo: tipoMapa, tamanho: tamanho, densidade: densidade)
        grade = g
        inicio = i
        alvo = a
        limparVisual()
        mensagem = "Novo setor gerado: \(tipoMapa.rawValue)."
    }

    func sortearPosicoes() {
        parar()
        var livres: [Pos] = []
        for r in 0..<grade.linhas {
            for c in 0..<grade.colunas {
                let p = Pos(r: r, c: c)
                if grade[p].passavel { livres.append(p) }
            }
        }
        guard livres.count >= 2 else { return }
        let distanciaMinima = (grade.linhas + grade.colunas) / 2
        var melhor = (livres[0], livres[1])
        var melhorDist = -1
        for _ in 0..<400 {
            let a = livres.randomElement()!
            let b = livres.randomElement()!
            let d = abs(a.r - b.r) + abs(a.c - b.c)
            if d > melhorDist {
                melhor = (a, b)
                melhorDist = d
            }
            if d >= distanciaMinima { break }
        }
        inicio = melhor.0
        alvo = melhor.1
        limparVisual()
        mensagem = "Novas coordenadas para o caçador e o mensageiro."
    }

    func prepararEdicao() {
        if fase != .parado || duelo != nil || !explorados.isEmpty || !rastro.isEmpty || !caminho.isEmpty {
            parar()
            limparVisual()
        }
    }

    func pintar(em p: Pos) {
        var g = grade
        let raio = tamanhoPincel - 1
        let protegidos: Set<Pos> = [inicio, alvo, predador, presa]
        var mudou = false
        for dr in -raio...raio {
            for dc in -raio...raio {
                let q = Pos(r: p.r + dr, c: p.c + dc)
                guard g.contem(q), !protegidos.contains(q), g[q] != pincel else { continue }
                g[q] = pincel
                mudou = true
            }
        }
        if mudou {
            grade = g
            if fase.ativa { mapaAlterado = true }
        }
    }

    func moverInicio(para p: Pos) {
        guard grade.contem(p), p != alvo, p != inicio else { return }
        if !grade[p].passavel { grade[p] = .rota }
        inicio = p
        predador = p
    }

    func moverAlvo(para p: Pos) {
        guard grade.contem(p), p != inicio, p != alvo else { return }
        if !grade[p].passavel { grade[p] = .rota }
        alvo = p
        presa = p
    }

    func limparVisual() {
        explorados = []
        fronteira = []
        caminho = []
        rastro = []
        duelo = nil
        dueloPasso = 0
        predador = inicio
        presa = alvo
        metricas = Metricas()
        previsto = nil
        fase = .parado
    }

    func parar() {
        tarefa?.cancel()
        tarefa = nil
        if fase.ativa {
            fase = .parado
            mensagem = "Simulação interrompida."
        }
    }

    // MARK: Caçada

    func iniciar() {
        parar()
        limparVisual()
        orcamentoPresa = 0
        estimador = EstimadorAlvo(presa: alvo)
        mapaAlterado = false
        if modo == .classico {
            metricas.custoOtimo = custoOtimoReferencia()
        }
        tarefa = Task { [weak self] in
            await self?.executar()
        }
    }

    private func custoOtimoReferencia() -> Double? {
        // A* com heurística consistente serve de gabarito para a eficiência.
        let r = Buscador.buscar(grade, de: inicio, ate: alvo, algoritmo: .aEstrela,
                                heuristica: diagonal ? .octil : .manhattan, diagonal: diagonal)
        return r.encontrou ? r.custo : nil
    }

    private enum FimCaminhada { case capturou, escapou, replanejar, cancelado }

    private func executar() async {
        var primeira = true
        while !Task.isCancelled {
            var destino = presa
            if modo == .fuga && guiagem == .antecipada && !primeira {
                let custoMedio = metricas.passos > 0 ? metricas.custoPercorrido / Double(metricas.passos) : 2
                destino = NavegacaoProporcional.calcularMira(grade, predador: predador, presa: presa,
                                                            estimador: estimador, custoMedio: custoMedio,
                                                            diagonal: diagonal)
            }
            var r = Buscador.buscar(grade, de: predador, ate: destino, algoritmo: algoritmo,
                                    heuristica: heuristica, diagonal: diagonal)
            if !r.encontrou && destino != presa {
                // Mira prevista sem rota (bolsão fechado): volta a mirar no alvo.
                metricas.nosExplorados += r.nosExplorados
                metricas.tempoMs += r.tempoMs
                r = Buscador.buscar(grade, de: predador, ate: presa, algoritmo: algoritmo,
                                    heuristica: heuristica, diagonal: diagonal)
            }
            metricas.tempoMs += r.tempoMs
            metricas.maxFronteira = max(metricas.maxFronteira, r.maxFronteira)

            fase = .explorando
            if primeira {
                mensagem = "Computador de navegação rodando \(algoritmo.nomeCompleto)."
            }
            await animarExploracao(r, turbo: !primeira)
            if Task.isCancelled { return }

            guard r.encontrou else {
                fase = .semCaminho
                mensagem = primeira
                    ? "Não existe rota até o mensageiro. Remova asteroides ou gere outro setor."
                    : "O caçador ficou cercado: os meteoros fecharam todas as rotas."
                tocar("Basso")
                finalizar(sucesso: false)
                return
            }

            if primeira { metricas.custoPlanejado = r.custo }
            caminho = r.caminho
            fase = .perseguindo
            if primeira { mensagem = "Rota travada. Motores em potência máxima." }

            switch await caminhar() {
            case .capturou:
                fase = .capturou
                mensagem = "Alvo interceptado! Custo \(metricas.custoPercorrido.fmt1) em \(metricas.passos) saltos."
                tocar("Glass")
                finalizar(sucesso: true)
                return
            case .escapou:
                fase = .escapou
                mensagem = "O mensageiro escapou após \(limitePassos) saltos."
                tocar("Basso")
                finalizar(sucesso: false)
                return
            case .replanejar:
                metricas.replanejamentos += 1
                primeira = false
            case .cancelado:
                return
            }
        }
    }

    private func animarExploracao(_ r: ResultadoBusca, turbo: Bool) async {
        var porTick = max(1, Int(pow(2.0, velocidade * 7)))
        if turbo { porTick *= 6 }
        var ex = Set<Pos>()
        var fr = Set<Pos>()
        let eventos = r.eventos
        var i = 0
        explorados = []
        fronteira = []
        while i < eventos.count {
            if Task.isCancelled { return }
            let fim = min(i + porTick, eventos.count)
            for e in eventos[i..<fim] {
                ex.insert(e.expandido)
                fr.remove(e.expandido)
                for a in e.adicionados where !ex.contains(a) {
                    fr.insert(a)
                }
            }
            metricas.nosExplorados += fim - i
            i = fim
            explorados = ex
            fronteira = fr
            await dormir(0.016)
        }
    }

    private func caminhar() async -> FimCaminhada {
        while caminho.count > 1 {
            if Task.isCancelled { return .cancelado }

            if mapaAlterado {
                mapaAlterado = false
                desbloquear(.sabotador)
                mensagem = "O setor mudou! Recalculando a rota."
                return .replanejar
            }

            let de = caminho[0]
            let para = caminho[1]
            let custo = grade.custoPasso(de: de, para: para)

            // Setores caros deixam a nave visivelmente mais lenta.
            let base = 0.03 + 0.17 * (1 - velocidade)
            let duracao = base * (0.6 + 0.22 * min(custo, 8))
            duracaoPasso = duracao
            await dormir(duracao)
            if Task.isCancelled { return .cancelado }
            if !grade[para].passavel { return .replanejar }

            caminho.removeFirst()
            predador = para
            rastro.append(para)
            metricas.custoPercorrido += custo
            metricas.passos += 1
            if grade[para] == .detritos || grade[para] == .tempestade { metricas.celulasHostis += 1 }

            if predador == presa { return .capturou }
            if metricas.passos >= limitePassos { return .escapou }

            switch modo {
            case .classico:
                break
            case .fuga:
                orcamentoPresa += custo
                var moveu = false
                while orcamentoPresa >= Fuga.custoPorSalto {
                    orcamentoPresa -= Fuga.custoPorSalto
                    presa = Fuga.proximaPosicao(grade, presa: presa, predador: predador, rng: &gerador)
                    moveu = true
                    if presa == predador { return .capturou }
                }
                // Retroalimentação: mede o alvo a cada salto e atualiza a velocidade estimada.
                estimador.observar(presa, tempo: metricas.custoPercorrido)

                if guiagem == .pura {
                    if moveu {
                        mensagem = "O mensageiro mudou de vetor. Recalculando."
                        return .replanejar
                    }
                } else if caminho.count > 1 {
                    let leitura = NavegacaoProporcional.medir(
                        grade, presa: presa, estimador: estimador,
                        destino: caminho[caminho.count - 1],
                        custoRestante: NavegacaoProporcional.custoRestante(grade, caminho))
                    metricas.zem = leitura.zem
                    metricas.tgo = leitura.tgo
                    previsto = leitura.previsto
                    if leitura.comando > ParametrosPN.limiar {
                        mensagem = "ZEM de \(leitura.zem.fmt1) células: corrigindo a rota."
                        return .replanejar
                    }
                }
            case .meteoros:
                if metricas.passos % 5 == 0, chuvaDeMeteoros() {
                    mensagem = "Meteoros bloquearam a rota! Replanejando."
                    return .replanejar
                }
            }
        }
        return predador == presa ? .capturou : .replanejar
    }

    /// Derruba meteoros; retorna true se algum caiu na rota restante.
    private func chuvaDeMeteoros() -> Bool {
        impactos += 1
        tocar("Submarine")
        var g = grade
        let adiante = Array(caminho.dropFirst(2))
        var novos: [Pos] = []
        for _ in 0..<Int.random(in: 3...6) {
            let p: Pos
            if !adiante.isEmpty && Bool.random() {
                p = adiante.randomElement()!
            } else {
                p = Pos(r: Int.random(in: 0..<g.linhas), c: Int.random(in: 0..<g.colunas))
            }
            if p == predador || p == presa { continue }
            g[p] = .asteroide
            novos.append(p)
        }
        grade = g
        let restante = Set(caminho)
        return novos.contains { restante.contains($0) }
    }

    private func finalizar(sucesso: Bool) {
        tarefa = nil
        registrar(RegistroCorrida(
            algoritmo: algoritmo, heuristica: heuristica,
            modo: modo == .fuga ? "\(modo.rawValue) · \(guiagem.rawValue)" : modo.rawValue,
            nos: metricas.nosExplorados, tempoMs: metricas.tempoMs,
            custo: sucesso ? metricas.custoPercorrido : nil,
            eficiencia: metricas.eficiencia, sucesso: sucesso))

        guard sucesso else { return }
        if let e = metricas.eficiencia, e >= 0.999 {
            desbloquear(.saltoPerfeito)
            if algoritmo == .gulosa { desbloquear(.pilotoSortudo) }
        }
        let livres = grade.celulas.filter { $0.passavel }.count
        if Double(metricas.nosExplorados) < 0.05 * Double(livres) { desbloquear(.sensorAfiado) }
        if metricas.celulasHostis >= 10 { desbloquear(.cascoChamuscado) }
        if modo == .fuga { desbloquear(.cacadorRecompensas) }
        if modo == .meteoros { desbloquear(.sobrevivente) }
    }

    // MARK: Comparativo de guiagem

    /// Roda as três guiagens no setor atual, sem animação, fora da thread principal.
    func compararGuiagens(rodadas: Int = 30) {
        guard !comparando else { return }
        parar()
        limparVisual()
        comparando = true
        mensagem = "Simulando \(rodadas) perseguições por guiagem neste setor..."
        let g = grade, i = inicio, a = alvo
        let alg = algoritmo, h = heuristica, d = diagonal
        Task { [weak self] in
            let resultado = await Task.detached(priority: .userInitiated) {
                ComparativoGuiagem.calcular(g, inicio: i, alvo: a, algoritmo: alg,
                                            heuristica: h, diagonal: d, rodadas: rodadas)
            }.value
            guard let self else { return }
            self.comparativo = resultado
            self.comparando = false
            self.mensagem = "Comparativo pronto: \(rodadas) rodadas por guiagem, mesmo setor e mesmas sementes."
            self.tocar("Hero")
        }
    }

    // MARK: Duelo

    func comparar() {
        parar()
        limparVisual()
        let g = Buscador.buscar(grade, de: inicio, ate: alvo, algoritmo: .gulosa,
                                heuristica: heuristica, diagonal: diagonal)
        let a = Buscador.buscar(grade, de: inicio, ate: alvo, algoritmo: .aEstrela,
                                heuristica: heuristica, diagonal: diagonal)
        let otimo = custoOtimoReferencia()
        let d = Duelo(gulosa: g, aEstrela: a)
        duelo = d
        dueloPasso = 0
        fase = .explorando
        mensagem = "Duelo de navegadores: Gulosa (vermelho) contra A* (azul) no mesmo setor."
        desbloquear(.esquadrao)

        let total = max(g.nosExplorados, a.nosExplorados)
        tarefa = Task { [weak self] in
            guard let self else { return }
            let porTick = max(1, Int(pow(2.0, self.velocidade * 7)))
            while self.dueloPasso < total {
                if Task.isCancelled { return }
                self.dueloPasso = min(total, self.dueloPasso + porTick)
                await self.dormir(0.016)
            }
            if Task.isCancelled { return }
            self.fase = .parado
            self.tarefa = nil
            self.mensagem = d.veredito
            self.tocar("Hero")
            for r in [a, g] {
                var e: Double?
                if r.encontrou, let o = otimo, r.custo > 0 { e = min(1, o / r.custo) }
                self.registrar(RegistroCorrida(
                    algoritmo: r.algoritmo, heuristica: self.heuristica, modo: "Duelo",
                    nos: r.nosExplorados, tempoMs: r.tempoMs,
                    custo: r.encontrou ? r.custo : nil, eficiencia: e, sucesso: r.encontrou))
            }
        }
    }

    // MARK: Utilidades

    private func registrar(_ r: RegistroCorrida) {
        historico.insert(r, at: 0)
        if historico.count > 14 { historico.removeLast() }
    }

    private func desbloquear(_ c: Conquista) {
        guard !conquistas.contains(c) else { return }
        conquistas.insert(c)
        tocar("Hero")
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) { toast = c }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            guard let self, self.toast == c else { return }
            withAnimation(.easeOut(duration: 0.3)) { self.toast = nil }
        }
    }

    private func tocar(_ som: String) {
        if somAtivo { Som.tocar(som) }
    }

    private func dormir(_ segundos: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(max(0.001, segundos) * 1_000_000_000))
    }
}
