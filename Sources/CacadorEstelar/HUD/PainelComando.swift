import SwiftUI

struct PainelComando: View {
    @EnvironmentObject var jogo: JogoModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                missao
                navegador
                modoJogo
                ferramenta
                setor
            }
            .padding(16)
        }
        .vidroHUD(jogo.algoritmo.cor)
    }

    // MARK: Missão

    private var missao: some View {
        SecaoHUD(titulo: "Missão", simbolo: "scope") {
            Button { jogo.iniciar() } label: {
                Label("Iniciar caçada", systemImage: "play.fill")
            }
            .buttonStyle(BotaoHUD(cor: jogo.algoritmo.cor, principal: true))
            .keyboardShortcut(.return, modifiers: .command)

            Button { jogo.comparar() } label: {
                Label("Duelo: Gulosa × A*", systemImage: "bolt.horizontal.fill")
            }
            .buttonStyle(BotaoHUD(cor: Color(nsColor: Paleta.violeta)))
            .keyboardShortcut("d", modifiers: .command)

            HStack(spacing: 8) {
                Button { jogo.parar() } label: {
                    Label("Parar", systemImage: "stop.fill")
                }
                .buttonStyle(BotaoHUD(cor: .white))
                .keyboardShortcut(.escape, modifiers: [])

                Button { jogo.parar(); jogo.limparVisual() } label: {
                    Label("Limpar", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(BotaoHUD(cor: .white))
            }

            HStack(spacing: 8) {
                Image(systemName: "tortoise.fill")
                Slider(value: $jogo.velocidade, in: 0...1)
                    .tint(Color.hudCiano)
                Image(systemName: "hare.fill")
            }
            .font(.system(size: 11))
            .foregroundStyle(Color.hudFraco)

            Toggle(isOn: $jogo.somAtivo) {
                Text("Efeitos sonoros").font(.system(size: 11)).foregroundStyle(Color.hudFraco)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(Color.hudCiano)
        }
    }

    // MARK: Navegador

    private var navegador: some View {
        SecaoHUD(titulo: "Computador de navegação", simbolo: "cpu") {
            HStack(spacing: 8) {
                ForEach(Algoritmo.allCases) { a in
                    CartaoAlgoritmo(algoritmo: a, selecionado: jogo.algoritmo == a) {
                        jogo.algoritmo = a
                    }
                }
            }

            HStack {
                Text("Heurística").font(.system(size: 11)).foregroundStyle(Color.hudFraco)
                Spacer()
                Picker("", selection: $jogo.heuristica) {
                    ForEach(Heuristica.allCases) { h in
                        Text(h.rawValue).tag(h)
                    }
                }
                .labelsHidden()
                .frame(width: 130)
            }

            Toggle(isOn: $jogo.diagonal) {
                Text("Saltos diagonais (custo ×√2)").font(.system(size: 11)).foregroundStyle(Color.hudFraco)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(Color.hudCiano)

            if !jogo.heuristica.admissivel(diagonal: jogo.diagonal) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Manhattan superestima com diagonais: o A* pode perder a rota ótima.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 10.5))
                .foregroundStyle(Color.hudOuro)
            }
        }
        .disabled(jogo.fase.ativa)
        .opacity(jogo.fase.ativa ? 0.55 : 1)
    }

    // MARK: Modo

    private var modoJogo: some View {
        SecaoHUD(titulo: "Modo de jogo", simbolo: "gamecontroller.fill") {
            VStack(spacing: 6) {
                ForEach(ModoJogo.allCases) { m in
                    let ativo = jogo.modo == m
                    Button { jogo.modo = m } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: m.simbolo)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(ativo ? Color.hudOuro : Color.hudFraco)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.rawValue)
                                    .font(.hud(11.5, .bold))
                                    .foregroundStyle(Color.hudTexto)
                                Text(m.descricao)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.hudFraco)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(9)
                        .background(RoundedRectangle(cornerRadius: 10).fill(ativo ? Color.hudOuro.opacity(0.1) : Color.white.opacity(0.025)))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ativo ? Color.hudOuro.opacity(0.6) : Color.clear, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                   .buttonStyle(.plain)
                }
            }

            if jogo.modo == .fuga {
                guiagem
            }
        }
        .disabled(jogo.fase.ativa)
        .opacity(jogo.fase.ativa ? 0.55 : 1)
    }

    // MARK: Guiagem (só no modo Perseguição)

    private var guiagem: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Guiagem do caçador")
                .font(.hud(10, .bold))
                .foregroundStyle(Color.hudTexto.opacity(0.85))

            Picker("", selection: $jogo.guiagem) {
                ForEach(Guiagem.allCases) { g in
                    Text(g.rawValue).tag(g)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: jogo.guiagem.simbolo)
                    .foregroundStyle(jogo.guiagem.cor)
                Text(jogo.guiagem.descricao)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 10))
            .foregroundStyle(Color.hudFraco)

            Button { jogo.compararGuiagens() } label: {
                if jogo.comparando {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Simulando...")
                    }
                } else {
                    Label("Comparar guiagens", systemImage: "chart.bar.xaxis")
                }
            }
            .buttonStyle(BotaoHUD(cor: Color(nsColor: Paleta.magenta)))
            .disabled(jogo.comparando)
        }
        .padding(.top, 4)
    }

    // MARK: Ferramenta de terreno

    private var ferramenta: some View {
        SecaoHUD(titulo: "Terraformador", simbolo: "paintbrush.pointed.fill") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(Terreno.allCases) { t in
                    let ativo = jogo.pincel == t
                    Button { jogo.pincel = t } label: {
                        VStack(spacing: 4) {
                            Image(systemName: t.simbolo)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(t.cor)
                                .shadow(color: t.cor.opacity(ativo ? 0.9 : 0), radius: 5)
                            Text(t.nomeCurto)
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(Color.hudTexto)
                            Text(t.textoCusto)
                                .font(.hud(9, .bold))
                                .foregroundStyle(Color.hudFraco)
                        }
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 9).fill(t.cor.opacity(ativo ? 0.16 : 0.03)))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(t.cor.opacity(ativo ? 0.85 : 0.12), lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Picker("", selection: $jogo.tamanhoPincel) {
                Text("1×1").tag(1)
                Text("3×3").tag(2)
                Text("5×5").tag(3)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text("Durante a caçada, pintar o setor sabota a rota e força o caçador a replanejar.")
                .font(.system(size: 10))
                .foregroundStyle(Color.hudFraco)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Setor

    private var setor: some View {
        SecaoHUD(titulo: "Setor", simbolo: "map.fill") {
            Picker("", selection: $jogo.tipoMapa) {
                ForEach(TipoMapa.allCases) { t in
                    Label(t.rawValue, systemImage: t.simbolo).tag(t)
                }
            }
            .labelsHidden()

            Picker("", selection: $jogo.tamanho) {
                ForEach(TamanhoGrade.allCases) { t in
                    Text(t.rotulo).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if jogo.tipoMapa == .aleatorio || jogo.tipoMapa == .natureza {
                HStack(spacing: 8) {
                    Image(systemName: "moon.fill").font(.system(size: 10)).foregroundStyle(Color.hudFraco)
                    Slider(value: $jogo.densidade, in: 0.05...0.45)
                        .tint(Color.hudCiano)
                }
            }

            HStack(spacing: 8) {
                Button { jogo.gerarMapa() } label: {
                    Label("Gerar setor", systemImage: "wand.and.stars")
                }
                .buttonStyle(BotaoHUD(cor: .hudCiano))
                .keyboardShortcut("g", modifiers: .command)

                Button { jogo.sortearPosicoes() } label: {
                    Label("Sortear A/B", systemImage: "shuffle")
                }
                .buttonStyle(BotaoHUD(cor: .white))
            }
        }
        .disabled(jogo.fase.ativa)
        .opacity(jogo.fase.ativa ? 0.55 : 1)
    }
}
