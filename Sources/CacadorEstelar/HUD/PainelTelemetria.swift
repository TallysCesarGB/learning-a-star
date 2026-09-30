import SwiftUI

struct PainelTelemetria: View {
    @EnvironmentObject var jogo: JogoModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                if let d = jogo.duelo {
                    duelo(d)
                } else {
                    telemetria
                }
                conquistas
                registro
            }
            .padding(16)
        }
        .vidroHUD(jogo.fase.cor)
    }

    // MARK: Telemetria ao vivo

    private var telemetria: some View {
        let m = jogo.metricas
        let cor = jogo.algoritmo.cor
        return SecaoHUD(titulo: "Telemetria", simbolo: "waveform.path.ecg") {
            HStack(spacing: 12) {
                MedidorArco(valor: m.eficiencia, cor: (m.eficiencia ?? 0) >= 0.999 ? .hudVerde : cor)
                VStack(spacing: 6) {
                    LeituraHUD(titulo: "Nós explorados", valor: "\(m.nosExplorados)",
                               simbolo: "circle.grid.3x3.fill", cor: cor)
                    LeituraHUD(titulo: "Convergência", valor: String(format: "%.3f ms", m.tempoMs),
                               simbolo: "timer", cor: .hudVerde)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                LeituraHUD(titulo: "Custo planejado", valor: m.custoPlanejado.map { $0.fmt1 } ?? "--",
                           simbolo: "point.topleft.down.curvedto.point.bottomright.up", cor: Color(nsColor: Paleta.violeta))
                LeituraHUD(titulo: "Custo percorrido", valor: m.custoPercorrido.fmt1,
                           simbolo: "flame.fill", cor: .hudBrasa)
                LeituraHUD(titulo: "Saltos", valor: "\(m.passos)",
                           simbolo: "arrow.triangle.turn.up.right.diamond.fill", cor: .hudCiano)
                LeituraHUD(titulo: "Replanejamentos", valor: "\(m.replanejamentos)",
                           simbolo: "arrow.triangle.2.circlepath", cor: Color(nsColor: Paleta.magenta))
                LeituraHUD(titulo: "Fronteira máx.", valor: "\(m.maxFronteira)",
                           simbolo: "square.stack.3d.up.fill", cor: .hudOuro)
                LeituraHUD(titulo: "Custo ótimo", valor: m.custoOtimo.map { $0.fmt1 } ?? "--",
                           simbolo: "checkmark.seal.fill", cor: .hudVerde)
            }
        }
    }

    // MARK: Duelo

    private func duelo(_ d: Duelo) -> some View {
        let g = d.gulosa
        let a = d.aEstrela
        let passo = jogo.dueloPasso
        let gPronto = passo >= g.nosExplorados
        let aPronto = passo >= a.nosExplorados

        return SecaoHUD(titulo: "Duelo de navegadores", simbolo: "bolt.horizontal.fill") {
            HStack {
                Chip("Gulosa", simbolo: gPronto ? "checkmark" : "ellipsis", cor: Algoritmo.gulosa.cor)
                Spacer()
                Text("vs").font(.hud(12, .heavy)).foregroundStyle(Color.hudFraco)
                Spacer()
                Chip("A*", simbolo: aPronto ? "checkmark" : "ellipsis", cor: Algoritmo.aEstrela.cor)
            }

            LinhaDuelo(titulo: "Nós explorados",
                       valorG: Double(min(passo, g.nosExplorados)),
                       valorA: Double(min(passo, a.nosExplorados)),
                       texto: { "\(Int($0))" })
            LinhaDuelo(titulo: "Tempo de convergência",
                       valorG: g.tempoMs, valorA: a.tempoMs,
                       texto: { String(format: "%.3f ms", $0) })
            LinhaDuelo(titulo: "Custo total da rota",
                       valorG: gPronto && g.encontrou ? g.custo : 0,
                       valorA: aPronto && a.encontrou ? a.custo : 0,
                       texto: { $0 > 0 ? $0.fmt1 : "--" })
            LinhaDuelo(titulo: "Saltos na rota",
                       valorG: gPronto ? Double(g.passos) : 0,
                       valorA: aPronto ? Double(a.passos) : 0,
                       texto: { $0 > 0 ? "\(Int($0))" : "--" })
            LinhaDuelo(titulo: "Fronteira máxima",
                       valorG: Double(g.maxFronteira), valorA: Double(a.maxFronteira),
                       texto: { "\(Int($0))" })

            if gPronto && aPronto {
                Text(d.veredito)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.hudTexto.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.04)))
            }
        }
    }

    // MARK: Conquistas

    private var conquistas: some View {
        SecaoHUD(titulo: "Conquistas \(jogo.conquistas.count)/\(Conquista.allCases.count)", simbolo: "rosette") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(Conquista.allCases) { c in
                    let ok = jogo.conquistas.contains(c)
                    VStack(spacing: 4) {
                        Image(systemName: ok ? c.simbolo : "lock.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(ok ? Color.hudOuro : Color.hudFraco.opacity(0.6))
                            .shadow(color: Color.hudOuro.opacity(ok ? 0.8 : 0), radius: 5)
                        Text(c.titulo)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(ok ? Color.hudTexto : Color.hudFraco)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(RoundedRectangle(cornerRadius: 9).fill(ok ? Color.hudOuro.opacity(0.09) : Color.white.opacity(0.02)))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(ok ? Color.hudOuro.opacity(0.45) : Color.clear, lineWidth: 1))
                    .help(c.descricao)
                }
            }
        }
    }

    // MARK: Registro de voo

    private var registro: some View {
        SecaoHUD(titulo: "Registro de voo", simbolo: "list.bullet.rectangle") {
            if jogo.historico.isEmpty {
                Text("Nenhuma missão registrada. Inicie uma caçada ou um duelo.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.hudFraco)
            }
            ForEach(jogo.historico) { h in
                HStack(spacing: 9) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(h.algoritmo.cor)
                        .frame(width: 3, height: 26)
                        .shadow(color: h.algoritmo.cor, radius: 3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(h.algoritmo.rawValue) com \(h.heuristica.rawValue)")
                            .font(.hud(10.5, .bold))
                            .foregroundStyle(Color.hudTexto)
                        Text("\(h.modo), \(h.nos) nós, \(String(format: "%.2f", h.tempoMs)) ms")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Color.hudFraco)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(h.sucesso ? (h.custo.map { $0.fmt1 } ?? "--") : "falhou")
                            .font(.hud(11, .bold))
                            .monospacedDigit()
                            .foregroundStyle(h.sucesso ? Color.hudTexto : Color.hudBrasa)
                        Text(Estrelas.texto(h.eficiencia))
                            .font(.system(size: 9))
                            .foregroundStyle(Color.hudOuro)
                    }
                }
            }
        }
    }
}
