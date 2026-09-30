import SwiftUI

// MARK: - Tokens

extension Color {
    static let hudCiano = Color(nsColor: Paleta.ciano)
    static let hudBrasa = Color(nsColor: Paleta.brasa)
    static let hudOuro = Color(nsColor: Paleta.ouro)
    static let hudVerde = Color(nsColor: Paleta.verde)
    static let hudTexto = Color.white.opacity(0.93)
    static let hudFraco = Color.white.opacity(0.55)
}

extension Font {
    /// Tipografia do HUD: SF Pro em largura expandida.
    static func hud(_ tamanho: CGFloat, _ peso: Font.Weight = .semibold) -> Font {
        .system(size: tamanho, weight: peso).width(.expanded)
    }
}

// MARK: - Painel de vidro

/// Cantoneiras de mira nos quatro cantos: a assinatura visual do HUD.
struct CantosHUD: Shape {
    var tamanho: CGFloat = 12

    func path(in r: CGRect) -> Path {
        let t = tamanho
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + t)); p.addLine(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + t, y: r.minY))
        p.move(to: CGPoint(x: r.maxX - t, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY + t))
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - t)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX - t, y: r.maxY))
        p.move(to: CGPoint(x: r.minX + t, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY - t))
        return p
    }
}

struct VidroHUD: ViewModifier {
    var destaque: Color

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [Color(red: 0.03, green: 0.07, blue: 0.14).opacity(0.80),
                                                      Color(red: 0.01, green: 0.02, blue: 0.06).opacity(0.88)],
                                             startPoint: .top, endPoint: .bottom))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [destaque.opacity(0.55), destaque.opacity(0.05), destaque.opacity(0.3)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .overlay(CantosHUD(tamanho: 11).stroke(destaque.opacity(0.9), lineWidth: 1.6).padding(-3))
            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
    }
}

extension View {
    func vidroHUD(_ destaque: Color = .hudCiano) -> some View {
        modifier(VidroHUD(destaque: destaque))
    }
}

struct SecaoHUD<Conteudo: View>: View {
    let titulo: String
    let simbolo: String
    @ViewBuilder var conteudo: Conteudo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: simbolo)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.hudCiano)
                Text(titulo)
                    .font(.hud(10.5, .bold))
                    .foregroundStyle(Color.hudTexto.opacity(0.85))
                Rectangle()
                    .fill(LinearGradient(colors: [Color.hudCiano.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
            }
            conteudo
        }
    }
}

// MARK: - Botões

struct BotaoHUD: ButtonStyle {
    var cor: Color
    var principal = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.hud(principal ? 13 : 11, .bold))
            .foregroundStyle(principal ? Color.black.opacity(0.85) : Color.hudTexto)
            .frame(maxWidth: .infinity)
            .padding(.vertical, principal ? 11 : 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(principal
                          ? AnyShapeStyle(LinearGradient(colors: [cor, cor.opacity(0.72)], startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(cor.opacity(0.12)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(principal ? Color.white.opacity(0.35) : cor.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: cor.opacity(principal ? 0.6 : 0), radius: 12)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct CartaoAlgoritmo: View {
    let algoritmo: Algoritmo
    let selecionado: Bool
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: algoritmo.simbolo)
                    Spacer()
                    Circle()
                        .fill(selecionado ? algoritmo.cor : Color.white.opacity(0.15))
                        .frame(width: 7, height: 7)
                        .shadow(color: algoritmo.cor.opacity(selecionado ? 1 : 0), radius: 4)
                }
                .foregroundStyle(algoritmo.cor)
                Text(algoritmo.rawValue)
                    .font(.hud(15, .heavy))
                    .foregroundStyle(Color.hudTexto)
                Text(algoritmo.formula)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.hudFraco)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 11).fill(algoritmo.cor.opacity(selecionado ? 0.17 : 0.03)))
            .overlay(RoundedRectangle(cornerRadius: 11)
                .strokeBorder(algoritmo.cor.opacity(selecionado ? 0.85 : 0.15), lineWidth: selecionado ? 1.5 : 1))
            .shadow(color: algoritmo.cor.opacity(selecionado ? 0.35 : 0), radius: 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: selecionado)
    }
}

struct Chip: View {
    let texto: String
    let simbolo: String?
    let cor: Color

    init(_ texto: String, simbolo: String? = nil, cor: Color) {
        self.texto = texto
        self.simbolo = simbolo
        self.cor = cor
    }

    var body: some View {
        HStack(spacing: 5) {
            if let simbolo { Image(systemName: simbolo).font(.system(size: 9, weight: .bold)) }
            Text(texto).font(.hud(10, .semibold))
        }
        .foregroundStyle(cor)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(cor.opacity(0.12)))
        .overlay(Capsule().strokeBorder(cor.opacity(0.45), lineWidth: 1))
    }
}

// MARK: - Leituras

struct LeituraHUD: View {
    let titulo: String
    let valor: String
    let simbolo: String
    var cor: Color = .hudCiano

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: simbolo)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(cor)
                Text(titulo)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.hudFraco)
                    .lineLimit(1)
            }
            Text(valor)
                .font(.hud(15, .bold))
                .monospacedDigit()
                .foregroundStyle(Color.hudTexto)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.leading, 11)
        .padding(.trailing, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.035)))
        .overlay(alignment: .leading) {
            Capsule().fill(cor).frame(width: 2.5).padding(.vertical, 8).padding(.leading, 3)
                .shadow(color: cor, radius: 3)
        }
    }
}

/// Mostrador em arco para a eficiência da rota.
struct MedidorArco: View {
    let valor: Double?
    let cor: Color

    var body: some View {
        let fracao = valor ?? 0
        return ZStack {
            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(90))
            Circle()
                .trim(from: 0.12, to: 0.12 + 0.76 * fracao)
                .stroke(cor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(90))
                .shadow(color: cor.opacity(0.9), radius: 6)
            VStack(spacing: 1) {
                Text(valor.map { String(format: "%.0f%%", $0 * 100) } ?? "--")
                    .font(.hud(21, .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Color.hudTexto)
                Text("eficiência")
                    .font(.hud(8, .semibold))
                    .foregroundStyle(Color.hudFraco)
                Text(Estrelas.texto(valor))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.hudOuro)
            }
        }
        .frame(width: 112, height: 112)
        .animation(.easeOut(duration: 0.6), value: fracao)
    }
}

struct LinhaDuelo: View {
    let titulo: String
    let valorG: Double
    let valorA: Double
    let texto: (Double) -> String

    var body: some View {
        let maximo = max(valorG, valorA, 0.000001)
        return VStack(alignment: .leading, spacing: 4) {
            Text(titulo)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.hudFraco)
            barra(valorG / maximo, cor: Algoritmo.gulosa.cor, rotulo: texto(valorG),
                  vence: valorG > 0 && valorA > 0 && valorG < valorA)
            barra(valorA / maximo, cor: Algoritmo.aEstrela.cor, rotulo: texto(valorA),
                  vence: valorG > 0 && valorA > 0 && valorA < valorG)
        }
    }

    private func barra(_ fracao: Double, cor: Color, rotulo: String, vence: Bool) -> some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(LinearGradient(colors: [cor.opacity(0.6), cor], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(3, geo.size.width * CGFloat(fracao)))
                        .shadow(color: cor.opacity(0.7), radius: 4)
                }
            }
            .frame(height: 7)
            Text(rotulo)
                .font(.hud(10, .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.hudTexto)
                .frame(width: 78, alignment: .trailing)
            Image(systemName: "crown.fill")
                .font(.system(size: 9))
                .foregroundStyle(Color.hudOuro)
                .opacity(vence ? 1 : 0)
        }
    }
}

struct ToastConquista: View {
    let conquista: Conquista

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.hudOuro.opacity(0.15)).frame(width: 46, height: 46)
                Circle().strokeBorder(Color.hudOuro.opacity(0.8), lineWidth: 1.5).frame(width: 46, height: 46)
                Image(systemName: conquista.simbolo)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.hudOuro)
                    .shadow(color: .hudOuro, radius: 6)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Conquista desbloqueada")
                    .font(.hud(9.5, .bold))
                    .foregroundStyle(Color.hudOuro)
                Text(conquista.titulo)
                    .font(.hud(15, .heavy))
                    .foregroundStyle(Color.hudTexto)
                Text(conquista.descricao)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.hudFraco)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .vidroHUD(.hudOuro)
    }
}
