import SwiftUI
import AppKit

/// Paleta compartilhada entre o HUD (SwiftUI) e a cena 3D (SceneKit).
enum Paleta {
    static let ciano   = NSColor(srgbRed: 0.31, green: 0.82, blue: 1.00, alpha: 1)
    static let brasa   = NSColor(srgbRed: 1.00, green: 0.36, blue: 0.22, alpha: 1)
    static let ouro    = NSColor(srgbRed: 1.00, green: 0.78, blue: 0.34, alpha: 1)
    static let verde   = NSColor(srgbRed: 0.36, green: 1.00, blue: 0.62, alpha: 1)
    static let magenta = NSColor(srgbRed: 1.00, green: 0.30, blue: 0.65, alpha: 1)
    static let violeta = NSColor(srgbRed: 0.66, green: 0.42, blue: 1.00, alpha: 1)
}

/// Posição (linha, coluna) de uma célula: um vértice do grafo implícito.
struct Pos: Hashable {
    var r: Int
    var c: Int
}

/// Setores do espaço. Todo custo é >= 1, então heurísticas geométricas são admissíveis.
enum Terreno: Int, CaseIterable, Identifiable {
    case rota, vacuo, nebulosa, detritos, tempestade, asteroide

    var id: Int { rawValue }

    var nome: String {
        switch self {
        case .rota:       return "Rota hiperespacial"
        case .vacuo:      return "Vácuo"
        case .nebulosa:   return "Nebulosa"
        case .detritos:   return "Campo de detritos"
        case .tempestade: return "Tempestade iônica"
        case .asteroide:  return "Asteroide"
        }
    }

    var nomeCurto: String {
        switch self {
        case .rota:       return "Rota"
        case .vacuo:      return "Vácuo"
        case .nebulosa:   return "Nebulosa"
        case .detritos:   return "Detritos"
        case .tempestade: return "Tempestade"
        case .asteroide:  return "Asteroide"
        }
    }

    var simbolo: String {
        switch self {
        case .rota:       return "arrow.forward"
        case .vacuo:      return "sparkles"
        case .nebulosa:   return "cloud.fill"
        case .detritos:   return "circle.hexagongrid.fill"
        case .tempestade: return "tornado"
        case .asteroide:  return "moon.fill"
        }
    }

    /// Custo para ENTRAR na célula (peso da aresta).
    var custo: Double {
        switch self {
        case .rota:       return 1
        case .vacuo:      return 2
        case .nebulosa:   return 3
        case .detritos:   return 5
        case .tempestade: return 8
        case .asteroide:  return .infinity
        }
    }

    var passavel: Bool { self != .asteroide }
    var textoCusto: String { passavel ? "×\(Int(custo))" : "∞" }

    var nsCor: NSColor {
        switch self {
        case .rota:       return Paleta.ciano
        case .vacuo:      return NSColor(srgbRed: 0.42, green: 0.50, blue: 0.68, alpha: 1)
        case .nebulosa:   return Paleta.violeta
        case .detritos:   return NSColor(srgbRed: 0.80, green: 0.62, blue: 0.42, alpha: 1)
        case .tempestade: return Paleta.magenta
        case .asteroide:  return NSColor(srgbRed: 0.55, green: 0.50, blue: 0.47, alpha: 1)
        }
    }

    var cor: Color { Color(nsColor: nsCor) }
}

/// Grade 2D armazenada em vetor linear; funciona como grafo implícito.
struct Grade {
    let linhas: Int
    let colunas: Int
    private(set) var celulas: [Terreno]

    init(linhas: Int, colunas: Int, preenchimento: Terreno = .vacuo) {
        self.linhas = linhas
        self.colunas = colunas
        self.celulas = Array(repeating: preenchimento, count: linhas * colunas)
    }

    func contem(_ p: Pos) -> Bool {
        p.r >= 0 && p.r < linhas && p.c >= 0 && p.c < colunas
    }

    subscript(_ p: Pos) -> Terreno {
        get { celulas[p.r * colunas + p.c] }
        set { celulas[p.r * colunas + p.c] = newValue }
    }

    /// Lista de adjacência gerada sob demanda: (vizinho, custo da aresta).
    func vizinhos(de p: Pos, diagonal: Bool) -> [(pos: Pos, custo: Double)] {
        var saida: [(pos: Pos, custo: Double)] = []
        saida.reserveCapacity(8)

        let ortogonais: [(Int, Int)] = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        for (dr, dc) in ortogonais {
            let n = Pos(r: p.r + dr, c: p.c + dc)
            if contem(n), self[n].passavel {
                saida.append((pos: n, custo: self[n].custo))
            }
        }

        if diagonal {
            let diagonais: [(Int, Int)] = [(-1, -1), (-1, 1), (1, -1), (1, 1)]
            for (dr, dc) in diagonais {
                let n = Pos(r: p.r + dr, c: p.c + dc)
                guard contem(n), self[n].passavel else { continue }
                // Não permite atravessar a quina entre dois asteroides.
                let a = Pos(r: p.r + dr, c: p.c)
                let b = Pos(r: p.r, c: p.c + dc)
                if self[a].passavel && self[b].passavel {
                    saida.append((pos: n, custo: self[n].custo * 2.0.squareRoot()))
                }
            }
        }
        return saida
    }

    func custoPasso(de a: Pos, para b: Pos) -> Double {
        let diagonal = a.r != b.r && a.c != b.c
        return self[b].custo * (diagonal ? 2.0.squareRoot() : 1)
    }
}

extension Double {
    var fmt1: String { isFinite ? String(format: "%.1f", self) : "∞" }
}
