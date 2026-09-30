import SwiftUI
import AppKit

// MARK: - Estratégias

enum Algoritmo: String, CaseIterable, Identifiable {
    case gulosa = "Gulosa"
    case aEstrela = "A*"

    var id: String { rawValue }
    var nomeCompleto: String { self == .gulosa ? "Busca Gulosa (Greedy Best-First)" : "A* (A-Star)" }
    var simbolo: String { self == .gulosa ? "flame.fill" : "scope" }
    var formula: String { self == .gulosa ? "f(n) = h(n)" : "f(n) = g(n) + h(n)" }
    var nsCor: NSColor { self == .gulosa ? Paleta.brasa : Paleta.ciano }
    var cor: Color { Color(nsColor: nsCor) }
}

enum Heuristica: String, CaseIterable, Identifiable {
    case manhattan = "Manhattan"
    case euclidiana = "Euclidiana"
    case octil = "Octil"
    case chebyshev = "Chebyshev"

    var id: String { rawValue }

    func valor(_ a: Pos, _ b: Pos) -> Double {
        let dr = Double(abs(a.r - b.r))
        let dc = Double(abs(a.c - b.c))
        switch self {
        case .manhattan:  return dr + dc
        case .euclidiana: return (dr * dr + dc * dc).squareRoot()
        case .octil:      return max(dr, dc) + (2.0.squareRoot() - 1) * min(dr, dc)
        case .chebyshev:  return max(dr, dc)
        }
    }

    /// Com custo mínimo = 1, só a Manhattan com diagonais superestima.
    func admissivel(diagonal: Bool) -> Bool {
        !(self == .manhattan && diagonal)
    }
}

// MARK: - Fila de prioridade (heap binário mínimo)

struct FilaPrioridade<T> {
    private var itens: [T] = []
    private let menor: (T, T) -> Bool

    init(menor: @escaping (T, T) -> Bool) {
        self.menor = menor
    }

    var vazia: Bool { itens.isEmpty }
    var count: Int { itens.count }

    mutating func inserir(_ x: T) {
        itens.append(x)
        subir(itens.count - 1)
    }

    mutating func remover() -> T? {
        guard !itens.isEmpty else { return nil }
        itens.swapAt(0, itens.count - 1)
        let x = itens.removeLast()
        if !itens.isEmpty { descer(0) }
        return x
    }

    private mutating func subir(_ inicio: Int) {
        var i = inicio
        while i > 0 {
            let pai = (i - 1) / 2
            if menor(itens[i], itens[pai]) {
                itens.swapAt(i, pai)
                i = pai
            } else {
                break
            }
        }
    }

    private mutating func descer(_ inicio: Int) {
        var i = inicio
        let n = itens.count
        while true {
            let esq = 2 * i + 1
            let dir = esq + 1
            var m = i
            if esq < n && menor(itens[esq], itens[m]) { m = esq }
            if dir < n && menor(itens[dir], itens[m]) { m = dir }
            if m == i { return }
            itens.swapAt(i, m)
            i = m
        }
    }
}

// MARK: - Resultado

/// Um passo da busca: nó retirado da fronteira e nós que entraram nela.
struct EventoBusca {
    let expandido: Pos
    let adicionados: [Pos]
}

struct ResultadoBusca {
    let algoritmo: Algoritmo
    let encontrou: Bool
    let caminho: [Pos]
    let custo: Double
    let eventos: [EventoBusca]
    let ordem: [Pos]
    let tempoMs: Double
    let maxFronteira: Int

    var nosExplorados: Int { eventos.count }
    var passos: Int { max(0, caminho.count - 1) }
}

// MARK: - Buscador

enum Buscador {

    static func buscar(_ grade: Grade,
                       de inicio: Pos,
                       ate alvo: Pos,
                       algoritmo: Algoritmo,
                       heuristica: Heuristica,
                       diagonal: Bool) -> ResultadoBusca {

        let t0 = DispatchTime.now().uptimeNanoseconds

        struct No {
            let pos: Pos
            let f: Double
            let g: Double
            let h: Double
        }

        // Desempate pelo menor h: com f igual, prefere quem parece mais perto do alvo.
        var aberta = FilaPrioridade<No>(menor: { a, b in
            a.f == b.f ? a.h < b.h : a.f < b.f
        })
        var g: [Pos: Double] = [inicio: 0]
        var pai: [Pos: Pos] = [:]
        var fechados = Set<Pos>()
        var eventos: [EventoBusca] = []
        var maxFronteira = 1
        var encontrou = false

        if grade.contem(inicio), grade.contem(alvo), grade[alvo].passavel {
            let h0 = heuristica.valor(inicio, alvo)
            aberta.inserir(No(pos: inicio, f: h0, g: 0, h: h0))
        }

        while let atual = aberta.remover() {
            if fechados.contains(atual.pos) { continue }
            // Entrada obsoleta do heap: o A* já encontrou g menor para esse nó.
            if algoritmo == .aEstrela, let melhor = g[atual.pos], atual.g > melhor { continue }

            fechados.insert(atual.pos)

            if atual.pos == alvo {
                encontrou = true
                eventos.append(EventoBusca(expandido: atual.pos, adicionados: []))
                break
            }

            var adicionados: [Pos] = []
            for (viz, custoAresta) in grade.vizinhos(de: atual.pos, diagonal: diagonal) {
                if fechados.contains(viz) { continue }
                let novoG = atual.g + custoAresta

                switch algoritmo {
                case .aEstrela:
                    // Relaxamento de aresta: aceita se o custo acumulado melhorou.
                    if novoG < g[viz, default: .infinity] {
                        g[viz] = novoG
                        pai[viz] = atual.pos
                        let h = heuristica.valor(viz, alvo)
                        aberta.inserir(No(pos: viz, f: novoG + h, g: novoG, h: h))
                        adicionados.append(viz)
                    }
                case .gulosa:
                    // Ignora g: cada nó entra na fronteira uma única vez, ordenado só por h.
                    if g[viz] == nil {
                        g[viz] = novoG
                        pai[viz] = atual.pos
                        let h = heuristica.valor(viz, alvo)
                        aberta.inserir(No(pos: viz, f: h, g: novoG, h: h))
                        adicionados.append(viz)
                    }
                }
            }
            eventos.append(EventoBusca(expandido: atual.pos, adicionados: adicionados))
            maxFronteira = max(maxFronteira, aberta.count)
        }

        var caminho: [Pos] = []
        if encontrou {
            var atual = alvo
            caminho.append(atual)
            while let p = pai[atual] {
                caminho.append(p)
                atual = p
            }
            caminho.reverse()
        }

        let t1 = DispatchTime.now().uptimeNanoseconds
        return ResultadoBusca(
            algoritmo: algoritmo,
            encontrou: encontrou,
            caminho: caminho,
            custo: encontrou ? (g[alvo] ?? 0) : .infinity,
            eventos: eventos,
            ordem: eventos.map { $0.expandido },
            tempoMs: Double(t1 - t0) / 1_000_000,
            maxFronteira: maxFronteira
        )
    }
}
