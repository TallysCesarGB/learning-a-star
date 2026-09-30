import SwiftUI
import AppKit

@main
struct CacadorEstelarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var jogo = JogoModel()

    var body: some Scene {
        WindowGroup("Caçador Estelar") {
            ContentView()
                .environmentObject(jogo)
                .frame(minWidth: 1280, minHeight: 780)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1560, height: 940)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

/// Garante foco e ícone no Dock quando rodado via `swift run`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

// MARK: - Layout

struct ContentView: View {
    @EnvironmentObject var jogo: JogoModel

    var body: some View {
        ZStack {
            VisaoEspacial(jogo: jogo)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                BarraSuperior()
                HStack(alignment: .top, spacing: 0) {
                    PainelComando()
                        .frame(width: 300)
                    Spacer(minLength: 0)
                    PainelTelemetria()
                        .frame(width: 310)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                BarraInferior()
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 16)

            if let c = jogo.toast {
                VStack {
                    ToastConquista(conquista: c)
                        .padding(.top, 96)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}

struct BarraSuperior: View {
    @EnvironmentObject var jogo: JogoModel

    var body: some View {
        let admissivel = jogo.heuristica.admissivel(diagonal: jogo.diagonal)
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Caçador Estelar")
                    .font(.hud(20, .black))
                    .foregroundStyle(LinearGradient(colors: [.white, .hudCiano], startPoint: .top, endPoint: .bottom))
                Text("Busca Gulosa e A* em um setor de \(jogo.grade.linhas) × \(jogo.grade.colunas)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.hudFraco)
            }

            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 34)

            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(jogo.fase.cor.opacity(0.15)).frame(width: 34, height: 34)
                    Image(systemName: jogo.fase.simbolo)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(jogo.fase.cor)
                        .shadow(color: jogo.fase.cor, radius: 6)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(jogo.fase.titulo)
                        .font(.hud(12.5, .heavy))
                        .foregroundStyle(jogo.fase.cor)
                    Text(jogo.mensagem)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.hudTexto.opacity(0.75))
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Chip(jogo.algoritmo.rawValue, simbolo: jogo.algoritmo.simbolo, cor: jogo.algoritmo.cor)
                Chip("h: \(jogo.heuristica.rawValue)", cor: .hudFraco)
                Chip(admissivel ? "admissível" : "não admissível",
                     simbolo: admissivel ? "checkmark.shield.fill" : "exclamationmark.triangle.fill",
                     cor: admissivel ? .hudVerde : .hudOuro)
                Chip(jogo.diagonal ? "8 direções" : "4 direções", cor: .hudFraco)
                Chip(jogo.modo.rawValue, simbolo: jogo.modo.simbolo, cor: .hudOuro)
            }
        }
        .padding(.leading, 76)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .vidroHUD(jogo.fase.cor)
    }
}

struct BarraInferior: View {
    @EnvironmentObject var jogo: JogoModel

    var body: some View {
        HStack(spacing: 18) {
            HStack(spacing: 4) {
                ForEach(ModoCamera.allCases) { m in
                    let ativo = jogo.camera == m
                    Button { jogo.camera = m } label: {
                        Label(m.rawValue, systemImage: m.simbolo)
                            .font(.hud(10.5, .bold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(ativo ? Color.hudCiano.opacity(0.2) : Color.clear))
                            .overlay(Capsule().strokeBorder(Color.hudCiano.opacity(ativo ? 0.8 : 0.18), lineWidth: 1))
                            .foregroundStyle(ativo ? Color.hudCiano : Color.hudFraco)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 22)

            HStack(spacing: 12) {
                ForEach(Terreno.allCases) { t in
                    HStack(spacing: 5) {
                        Circle().fill(t.cor).frame(width: 7, height: 7).shadow(color: t.cor, radius: 3)
                        Text(t.nomeCurto).font(.system(size: 10)).foregroundStyle(Color.hudTexto.opacity(0.8))
                        Text(t.textoCusto).font(.hud(9.5, .bold)).foregroundStyle(Color.hudFraco)
                    }
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 14) {
                dica("hand.draw.fill", "Pintar e arrastar A/B")
                dica("rotate.3d", "Botão direito ou ⌥ orbita")
                dica("plus.magnifyingglass", "Rolagem aproxima")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .vidroHUD()
    }

    private func dica(_ simbolo: String, _ texto: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: simbolo).font(.system(size: 10))
            Text(texto).font(.system(size: 10))
        }
        .foregroundStyle(Color.hudFraco)
    }
}
