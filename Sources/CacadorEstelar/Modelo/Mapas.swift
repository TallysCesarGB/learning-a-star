import Foundation

enum TipoMapa: String, CaseIterable, Identifiable {
    case vazio = "Setor limpo"
    case aleatorio = "Cinturão de asteroides"
    case labirinto = "Estação em ruínas"
    case natureza = "Nebulosa selvagem"

    var id: String { rawValue }

    var simbolo: String {
        switch self {
        case .vazio:     return "circle.dashed"
        case .aleatorio: return "die.face.5"
        case .labirinto: return "square.grid.3x3"
        case .natureza:  return "cloud.fill"
        }
    }
}

enum TamanhoGrade: String, CaseIterable, Identifiable {
    case pequeno, medio, grande

    var id: String { rawValue }

    var linhas: Int {
        switch self {
        case .pequeno: return 21
        case .medio:   return 29
        case .grande:  return 37
        }
    }

    var colunas: Int {
        switch self {
        case .pequeno: return 31
        case .medio:   return 43
        case .grande:  return 55
        }
    }

    var rotulo: String { "\(linhas)×\(colunas)" }
}

enum GeradorMapa {

    static func gerar(_ tipo: TipoMapa, linhas: Int, colunas: Int, densidade: Double) -> Grade {
        switch tipo {
        case .vazio:     return Grade(linhas: linhas, colunas: colunas, preenchimento: .vacuo)
        case .aleatorio: return aleatorio(linhas: linhas, colunas: colunas, densidade: densidade)
        case .labirinto: return labirinto(linhas: linhas, colunas: colunas)
        case .natureza:  return natureza(linhas: linhas, colunas: colunas, densidade: densidade)
        }
    }

    // MARK: Cinturão de asteroides

    private static func aleatorio(linhas: Int, colunas: Int, densidade: Double) -> Grade {
        var g = Grade(linhas: linhas, colunas: colunas, preenchimento: .vacuo)
        for r in 0..<linhas {
            for c in 0..<colunas {
                let x = Double.random(in: 0..<1)
                let p = Pos(r: r, c: c)
                if x < densidade {
                    g[p] = .asteroide
                } else if x < densidade + 0.07 {
                    g[p] = .detritos
                } else if x < densidade + 0.14 {
                    g[p] = .nebulosa
                } else if x < densidade + 0.30 {
                    g[p] = .rota
                }
            }
        }
        return g
    }

    // MARK: Estação em ruínas (labirinto por DFS + atalhos)

    private static func labirinto(linhas: Int, colunas: Int) -> Grade {
        var g = Grade(linhas: linhas, colunas: colunas, preenchimento: .asteroide)
        let origem = Pos(r: 1, c: 1)
        var visitados: Set<Pos> = [origem]
        var pilha: [Pos] = [origem]
        g[origem] = .rota

        while let atual = pilha.last {
            let direcoes: [(Int, Int)] = [(0, 2), (0, -2), (2, 0), (-2, 0)].shuffled()
            var avancou = false
            for (dr, dc) in direcoes {
                let n = Pos(r: atual.r + dr, c: atual.c + dc)
                if n.r > 0, n.r < linhas - 1, n.c > 0, n.c < colunas - 1, !visitados.contains(n) {
                    g[Pos(r: atual.r + dr / 2, c: atual.c + dc / 2)] = .rota
                    g[n] = .rota
                    visitados.insert(n)
                    pilha.append(n)
                    avancou = true
                    break
                }
            }
            if !avancou { pilha.removeLast() }
        }

        // Atalhos (criam ciclos) e variação de custo: é aqui que Gulosa e A* divergem.
        for r in 1..<(linhas - 1) {
            for c in 1..<(colunas - 1) {
                let p = Pos(r: r, c: c)
                let x = Double.random(in: 0..<1)
                if g[p] == .asteroide, x < 0.10 {
                    g[p] = [Terreno.detritos, .tempestade, .vacuo].randomElement()!
                } else if g[p] == .rota, x < 0.18 {
                    g[p] = [Terreno.vacuo, .nebulosa].randomElement()!
                }
            }
        }
        return g
    }

    // MARK: Nebulosa selvagem (ruído de valor suavizado)

    private static func natureza(linhas: Int, colunas: Int, densidade: Double) -> Grade {
        var g = Grade(linhas: linhas, colunas: colunas)
        let base = ruido(linhas: linhas, colunas: colunas, escala: 9)
        let detalhe = ruido(linhas: linhas, colunas: colunas, escala: 3)
        let limiarAsteroide = 0.84 - densidade * 0.45

        for r in 0..<linhas {
            for c in 0..<colunas {
                let i = r * colunas + c
                let v = 0.7 * base[i] + 0.3 * detalhe[i]
                let t: Terreno
                if v < 0.27 { t = .tempestade }
                else if v < 0.35 { t = .detritos }
                else if v < 0.56 { t = .vacuo }
                else if v < limiarAsteroide { t = .nebulosa }
                else { t = .asteroide }
                g[Pos(r: r, c: c)] = t
            }
        }

        // Duas rotas hiperespaciais sinuosas cruzando o setor.
        var r = Int.random(in: (linhas / 4)...(3 * linhas / 4))
        for c in 0..<colunas {
            g[Pos(r: r, c: c)] = .rota
            if Int.random(in: 0..<4) == 0 {
                r = min(linhas - 2, max(1, r + Int.random(in: -1...1)))
                g[Pos(r: r, c: c)] = .rota
            }
        }
        var c = Int.random(in: (colunas / 4)...(3 * colunas / 4))
        for rr in 0..<linhas {
            g[Pos(r: rr, c: c)] = .rota
            if Int.random(in: 0..<4) == 0 {
                c = min(colunas - 2, max(1, c + Int.random(in: -1...1)))
                g[Pos(r: rr, c: c)] = .rota
            }
        }
        return g
    }

    private static func ruido(linhas: Int, colunas: Int, escala: Int) -> [Double] {
        let gl = linhas / escala + 2
        let gc = colunas / escala + 2
        let malha = (0..<(gl * gc)).map { _ in Double.random(in: 0...1) }
        func suave(_ t: Double) -> Double { t * t * (3 - 2 * t) }

        var saida = [Double](repeating: 0, count: linhas * colunas)
        for r in 0..<linhas {
            for c in 0..<colunas {
                let fr = Double(r) / Double(escala)
                let fc = Double(c) / Double(escala)
                let r0 = Int(fr), c0 = Int(fc)
                let tr = suave(fr - Double(r0))
                let tc = suave(fc - Double(c0))
                let a = malha[r0 * gc + c0]
                let b = malha[r0 * gc + c0 + 1]
                let d = malha[(r0 + 1) * gc + c0]
                let e = malha[(r0 + 1) * gc + c0 + 1]
                let topo = a + (b - a) * tc
                let baixo = d + (e - d) * tc
                saida[r * colunas + c] = topo + (baixo - topo) * tr
            }
        }
        return saida
    }
}
