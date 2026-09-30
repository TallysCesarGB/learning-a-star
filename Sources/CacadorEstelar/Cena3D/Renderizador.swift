import AppKit
import SceneKit

/// Mantém a cena SceneKit sincronizada com o JogoModel.
/// A cada mudança publicada, compara o estado novo com o último renderizado
/// e só altera os nós que realmente mudaram.
final class Renderizador: NSObject {

    let cena = SCNScene()
    let cameraNo = SCNNode()

    private let mundo = SCNNode()
    private let caminhoNo = SCNNode()
    private let rastroNo = SCNNode()
    private let efeitos = SCNNode()
    private let cursorNo = SCNNode()
    private var moldura = SCNNode()
    private var base = SCNNode()
    private let lib = Biblioteca()

    private var linhas = 0
    private var colunas = 0
    private var placas: [SCNNode] = []
    private var decor: [SCNNode?] = []
    private var ovExplorado: [SCNNode?] = []
    private var ovFronteira: [SCNNode?] = []
    private var ovGulosa: [SCNNode?] = []
    private var ovAEstrela: [SCNNode?] = []
    private var terrenos: [Terreno] = []
    private var estados: [UInt8] = []

    private var algoritmoAtual: Algoritmo = .aEstrela
    private var caminhosAtuais: [[Pos]] = []
    private var rastroContagem = 0
    private var predadorPos: Pos?
    private var presaPos: Pos?
    private var inicioPos: Pos?
    private var alvoPos: Pos?
    private var faseAnterior: Fase = .parado
    private var impactosAnteriores = 0
    private var modoCamera: ModoCamera?
    private var arrasto: Arrasto?

    private let predador: Nave
    private let presa: Nave
    private let farolA: SCNNode
    private let farolB: SCNNode

    private var yaw: CGFloat = 0
    private var pitch: CGFloat = 0.9
    private var zoom: CGFloat = 1

    private enum Arrasto { case inicio, alvo, pintura }
    private enum Efeito { case nenhum, surgir, queda }

    override init() {
        predador = Naves.interceptador(cor: Algoritmo.aEstrela.nsCor)
        presa = Naves.mensageiro()
        farolA = Naves.farol(cor: Paleta.ouro, letra: "A")
        farolB = Naves.farol(cor: Paleta.verde, letra: "B")
        super.init()
        montarCena()
    }

    // MARK: - Montagem

    private func montarCena() {
        let ceu = Texturas.ceuEstrelado()
        cena.background.contents = ceu
        cena.lightingEnvironment.contents = ceu
        cena.lightingEnvironment.intensity = 1.2

        let cam = SCNCamera()
        cam.fieldOfView = 42
        cam.zNear = 0.1
        cam.zFar = 600
        cam.wantsHDR = true
        cam.wantsExposureAdaptation = false
        cam.bloomIntensity = 1.1
        cam.bloomThreshold = 0.62
        cam.bloomBlurRadius = 14
        cam.vignettingIntensity = 0.55
        cam.vignettingPower = 0.9
        cam.colorFringeStrength = 0.5
        cameraNo.camera = cam
        cena.rootNode.addChildNode(cameraNo)

        let ambiente = SCNLight()
        ambiente.type = .ambient
        ambiente.intensity = 180
        ambiente.color = NSColor(srgbRed: 0.45, green: 0.55, blue: 0.9, alpha: 1)
        let an = SCNNode()
        an.light = ambiente
        cena.rootNode.addChildNode(an)

        let sol = SCNLight()
        sol.type = .directional
        sol.intensity = 1100
        sol.color = NSColor(srgbRed: 1.0, green: 0.93, blue: 0.85, alpha: 1)
        sol.castsShadow = true
        sol.shadowSampleCount = 8
        sol.shadowRadius = 4
        sol.shadowMapSize = CGSize(width: 2048, height: 2048)
        sol.shadowColor = NSColor.black.withAlphaComponent(0.55)
        sol.orthographicScale = 40
        sol.automaticallyAdjustsShadowProjection = true
        let sn = SCNNode()
        sn.light = sol
        sn.eulerAngles = SCNVector3(-0.95, 0.55, 0)
        cena.rootNode.addChildNode(sn)

        let contraluz = SCNLight()
        contraluz.type = .directional
        contraluz.intensity = 500
        contraluz.color = Paleta.ciano
        let cn = SCNNode()
        cn.light = contraluz
        cn.eulerAngles = SCNVector3(-0.4, CGFloat.pi + 0.4, 0)
        cena.rootNode.addChildNode(cn)

        for n in [mundo, caminhoNo, rastroNo, efeitos] {
            cena.rootNode.addChildNode(n)
        }

        cursorNo.geometry = lib.cursor
        cursorNo.eulerAngles.x = -.pi / 2
        cursorNo.isHidden = true
        cena.rootNode.addChildNode(cursorNo)

        for n in [predador.no, presa.no, farolA, farolB] {
            cena.rootNode.addChildNode(n)
        }
    }

    private func montarMoldura() {
        moldura.removeFromParentNode()
        base.removeFromParentNode()

        moldura = SCNNode()
        let w = CGFloat(colunas) + 0.3
        let h = CGFloat(linhas) + 0.3
        let e: CGFloat = 0.06
        let material = Materiais.brilho(Paleta.ciano.withAlphaComponent(0.8))
        let barras: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (w, e, 0, -h / 2), (w, e, 0, h / 2), (e, h, -w / 2, 0), (e, h, w / 2, 0)
        ]
        for (bw, bl, x, z) in barras {
            let b = SCNBox(width: bw, height: 0.05, length: bl, chamferRadius: 0)
            b.materials = [material]
            let n = SCNNode(geometry: b)
            n.position = SCNVector3(x, -0.02, z)
            moldura.addChildNode(n)
        }
        cena.rootNode.addChildNode(moldura)

        let largura = w + 10, altura = h + 10
        let plano = SCNPlane(width: largura, height: altura)
        let m = Materiais.holograma(Texturas.gradeHolo(), aditivo: true)
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(largura / 2, altura / 2, 1)
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        plano.materials = [m]
        base = SCNNode(geometry: plano)
        base.eulerAngles.x = -.pi / 2
        base.position = SCNVector3(0, -0.3, 0)
        cena.rootNode.addChildNode(base)
    }

    // MARK: - Coordenadas

    private func mundoPos(_ p: Pos) -> SCNVector3 {
        SCNVector3(CGFloat(p.c) - CGFloat(colunas - 1) / 2, 0, CGFloat(p.r) - CGFloat(linhas - 1) / 2)
    }

    private func celula(x: CGFloat, z: CGFloat) -> Pos? {
        let c = Int((x + CGFloat(colunas - 1) / 2).rounded())
        let r = Int((z + CGFloat(linhas - 1) / 2).rounded())
        guard r >= 0, r < linhas, c >= 0, c < colunas else { return nil }
        return Pos(r: r, c: c)
    }

    /// Converte um ponto da tela em célula: raio da câmera intersectado com o plano do topo das placas.
    func celula(em ponto: CGPoint, na vista: SCNView) -> Pos? {
        let a = vista.unprojectPoint(SCNVector3(ponto.x, ponto.y, 0))
        let b = vista.unprojectPoint(SCNVector3(ponto.x, ponto.y, 1))
        let dy = b.y - a.y
        guard abs(dy) > 0.00001 else { return nil }
        let t = (0.07 - a.y) / dy
        guard t > 0 else { return nil }
        return celula(x: a.x + (b.x - a.x) * t, z: a.z + (b.z - a.z) * t)
    }

    // MARK: - Sincronização

    @MainActor
    func atualizar(com j: JogoModel) {
        let houveImpacto = j.impactos != impactosAnteriores
        impactosAnteriores = j.impactos

        if j.grade.linhas != linhas || j.grade.colunas != colunas {
            reconstruir(j.grade)
            modoCamera = nil
        } else {
            atualizarTerreno(j.grade, queda: houveImpacto)
        }
        if houveImpacto { tremerCamera() }

        if j.algoritmo != algoritmoAtual {
            algoritmoAtual = j.algoritmo
            recolorir()
        }

        atualizarSobreposicoes(j)
        atualizarCaminhos(j)
        atualizarRastro(j)
        atualizarFarois(j)
        atualizarNaves(j)

        if j.fase != faseAnterior {
            if j.fase == .capturou { explodir(em: j.presa) }
            faseAnterior = j.fase
        }

        if modoCamera != j.camera {
            let animar = modoCamera != nil
            modoCamera = j.camera
            posicionarCamera(animado: animar)
        }
    }

    private func reconstruir(_ g: Grade) {
        for pai in [mundo, caminhoNo, rastroNo] {
            pai.childNodes.forEach { $0.removeFromParentNode() }
        }
        linhas = g.linhas
        colunas = g.colunas
        let n = linhas * colunas
        placas = []
        placas.reserveCapacity(n)
        decor = Array(repeating: nil, count: n)
        ovExplorado = Array(repeating: nil, count: n)
        ovFronteira = Array(repeating: nil, count: n)
        ovGulosa = Array(repeating: nil, count: n)
        ovAEstrela = Array(repeating: nil, count: n)
        terrenos = g.celulas
        estados = Array(repeating: 0, count: n)
        caminhosAtuais = []
        rastroContagem = 0
        predadorPos = nil
        presaPos = nil
        inicioPos = nil
        alvoPos = nil

        for i in 0..<n {
            let p = Pos(r: i / colunas, c: i % colunas)
            let placa = SCNNode(geometry: lib.placa(terrenos[i]))
            placa.position = mundoPos(p)
            mundo.addChildNode(placa)
            placas.append(placa)
            colocarDecoracao(i, terrenos[i], efeito: .nenhum)
        }
        montarMoldura()
    }

    private func atualizarTerreno(_ g: Grade, queda: Bool) {
        let novos = g.celulas
        guard novos.count == terrenos.count else { return }
        for i in 0..<novos.count where novos[i] != terrenos[i] {
            terrenos[i] = novos[i]
            placas[i].geometry = lib.placa(novos[i])
            colocarDecoracao(i, novos[i], efeito: (queda && novos[i] == .asteroide) ? .queda : .surgir)
        }
    }

    private func colocarDecoracao(_ i: Int, _ t: Terreno, efeito: Efeito) {
        decor[i]?.removeFromParentNode()
        decor[i] = nil
        let placa = placas[i]

        if efeito == .surgir {
            placa.scale = SCNVector3(0.55, 0.55, 0.55)
            let s = SCNAction.scale(to: 1, duration: 0.2)
            s.timingMode = .easeOut
            placa.runAction(s)
        }

        guard let d = lib.decoracao(t) else { return }
        placa.addChildNode(d)
        decor[i] = d

        if efeito == .queda {
            let final = d.position
            d.position = SCNVector3(final.x, final.y + 10, final.z)
            let cair = SCNAction.move(to: final, duration: 0.6)
            cair.timingMode = .easeIn
            let alvo = placa.position
            d.runAction(cair) { [weak self] in
                DispatchQueue.main.async { self?.poeira(em: alvo) }
            }
        }
    }

    private func recolorir() {
        let geo = lib.explorada(algoritmoAtual)
        for no in ovExplorado { no?.geometry = geo }
        predador.colorir(algoritmoAtual.nsCor)
        caminhosAtuais = []
    }

    // MARK: Sobreposições (explorado, fronteira, duelo)

    @MainActor
    private func atualizarSobreposicoes(_ j: JogoModel) {
        let n = linhas * colunas
        guard n > 0 else { return }
        var novo = [UInt8](repeating: 0, count: n)

        func indice(_ p: Pos) -> Int? {
            (p.r >= 0 && p.r < linhas && p.c >= 0 && p.c < colunas) ? p.r * colunas + p.c : nil
        }
        for p in j.explorados { if let i = indice(p) { novo[i] |= 1 } }
        for p in j.fronteira { if let i = indice(p) { novo[i] |= 2 } }
        if let d = j.duelo {
            for p in d.gulosa.ordem.prefix(j.dueloPasso) { if let i = indice(p) { novo[i] |= 4 } }
            for p in d.aEstrela.ordem.prefix(j.dueloPasso) { if let i = indice(p) { novo[i] |= 8 } }
        }

        for i in 0..<n where novo[i] != estados[i] {
            let e = novo[i]
            definir(&ovExplorado, i, ligado: e & 1 != 0) {
                let no = SCNNode(geometry: self.lib.explorada(self.algoritmoAtual))
                no.eulerAngles.x = -.pi / 2
                no.position = SCNVector3(0, 0.085, 0)
                no.castsShadow = false
                return no
            }
            definir(&ovFronteira, i, ligado: e & 2 != 0) {
                let no = SCNNode(geometry: self.lib.aro)
                no.position = SCNVector3(0, 0.12, 0)
                no.castsShadow = false
                return no
            }
            definir(&ovGulosa, i, ligado: e & 4 != 0) {
                let no = SCNNode(geometry: self.lib.meia(.gulosa))
                no.eulerAngles.x = -.pi / 2
                no.position = SCNVector3(-0.22, 0.086, -0.22)
                no.castsShadow = false
                return no
            }
            definir(&ovAEstrela, i, ligado: e & 8 != 0) {
                let no = SCNNode(geometry: self.lib.meia(.aEstrela))
                no.eulerAngles.x = -.pi / 2
                no.position = SCNVector3(0.22, 0.087, 0.22)
                no.castsShadow = false
                return no
            }
            estados[i] = e
        }
    }

    private func definir(_ lista: inout [SCNNode?], _ i: Int, ligado: Bool, criar: () -> SCNNode) {
        if ligado {
            if let no = lista[i] {
                if no.isHidden {
                    no.isHidden = false
                    surgir(no)
                }
            } else {
                let no = criar()
                placas[i].addChildNode(no)
                lista[i] = no
                surgir(no)
            }
        } else {
            lista[i]?.isHidden = true
        }
    }

    private func surgir(_ no: SCNNode) {
        no.opacity = 0
        no.runAction(.fadeIn(duration: 0.22))
    }

    // MARK: Rotas

    @MainActor
    private func atualizarCaminhos(_ j: JogoModel) {
        var desejados: [([Pos], Algoritmo, CGFloat)] = []
        if let d = j.duelo {
            if j.dueloPasso >= d.gulosa.ordem.count { desejados.append((d.gulosa.caminho, .gulosa, -0.14)) }
            if j.dueloPasso >= d.aEstrela.ordem.count { desejados.append((d.aEstrela.caminho, .aEstrela, 0.14)) }
        }
        if j.caminho.count > 1 { desejados.append((j.caminho, j.algoritmo, 0)) }

        let chaves = desejados.map { $0.0 }
        if chaves == caminhosAtuais { return }
        caminhosAtuais = chaves
        caminhoNo.childNodes.forEach { $0.removeFromParentNode() }
        for (pontos, alg, deslocamento) in desejados {
            desenharLaser(pontos, alg, deslocamento)
        }
    }

    private func desenharLaser(_ pts: [Pos], _ alg: Algoritmo, _ desl: CGFloat) {
        guard pts.count > 1 else { return }
        let altura: CGFloat = 0.34
        let segmento = lib.laser(alg)
        let ponto = lib.ponto(alg)

        func posicao(_ p: Pos) -> SCNVector3 {
            let v = mundoPos(p)
            return SCNVector3(v.x + desl, altura, v.z + desl)
        }

        for k in 0..<pts.count {
            let a = posicao(pts[k])
            if k == 0 || k == pts.count - 1 || k % 3 == 0 {
                let p = SCNNode(geometry: ponto)
                p.position = a
                p.castsShadow = false
                caminhoNo.addChildNode(p)
            }
            guard k + 1 < pts.count else { continue }
            let b = posicao(pts[k + 1])
            let dx = b.x - a.x
            let dz = b.z - a.z
            let comprimento = (dx * dx + dz * dz).squareRoot()

            let pivo = SCNNode()
            pivo.position = SCNVector3((a.x + b.x) / 2, altura, (a.z + b.z) / 2)
            pivo.eulerAngles.y = atan2(dx, dz)
            let seg = SCNNode(geometry: segmento)
            seg.eulerAngles.x = .pi / 2
            seg.scale = SCNVector3(1, comprimento, 1)
            seg.castsShadow = false
            pivo.addChildNode(seg)
            caminhoNo.addChildNode(pivo)
        }
    }

    @MainActor
    private func atualizarRastro(_ j: JogoModel) {
        if j.rastro.count < rastroContagem {
            rastroNo.childNodes.forEach { $0.removeFromParentNode() }
            rastroContagem = 0
        }
        guard j.rastro.count > rastroContagem else { return }
        for p in j.rastro[rastroContagem...] {
            let n = SCNNode(geometry: lib.pontoRastro)
            var v = mundoPos(p)
            v.y = 0.16
            n.position = v
            n.castsShadow = false
            rastroNo.addChildNode(n)
        }
        rastroContagem = j.rastro.count
    }

    // MARK: Faróis e naves

    @MainActor
    private func atualizarFarois(_ j: JogoModel) {
        if inicioPos != j.inicio {
            inicioPos = j.inicio
            farolA.position = mundoPos(j.inicio)
        }
        if alvoPos != j.alvo {
            alvoPos = j.alvo
            farolB.position = mundoPos(j.alvo)
        }
    }

    @MainActor
    private func atualizarNaves(_ j: JogoModel) {
        mover(predador.no, anterior: &predadorPos, para: j.predador, olharPara: j.presa, duracao: j.duracaoPasso)
        mover(presa.no, anterior: &presaPos, para: j.presa, olharPara: nil, duracao: 0.35)
        presa.no.isHidden = j.fase == .capturou
    }

    private func mover(_ no: SCNNode, anterior: inout Pos?, para p: Pos, olharPara alvo: Pos?, duracao: Double) {
        guard anterior != p else { return }
        var destino = mundoPos(p)
        destino.y = 0.65

        var salto = true
        if let a = anterior { salto = abs(a.r - p.r) + abs(a.c - p.c) > 2 }

        var direcao: (CGFloat, CGFloat)?
        if let a = anterior, !salto {
            direcao = (CGFloat(p.c - a.c), CGFloat(p.r - a.r))
        } else if let o = alvo, o != p {
            direcao = (CGFloat(o.c - p.c), CGFloat(o.r - p.r))
        }
        anterior = p

        no.removeAction(forKey: "mover")
        if salto {
            no.position = destino
            if let d = direcao { no.eulerAngles.y = atan2(d.0, d.1) }
            return
        }
        var acoes: [SCNAction] = [.move(to: destino, duration: duracao)]
        if let d = direcao {
            acoes.append(.rotateTo(x: 0, y: atan2(d.0, d.1), z: 0,
                                   duration: min(duracao, 0.22), usesShortestUnitArc: true))
        }
        no.runAction(.group(acoes), forKey: "mover")
    }

    // MARK: Efeitos

    private func explodir(em p: Pos) {
        var v = mundoPos(p)
        v.y = 0.65
        let no = SCNNode()
        no.position = v
        no.addParticleSystem(Efeitos.explosao(cor: Paleta.verde))
        no.addParticleSystem(Efeitos.explosao(cor: Paleta.ouro, intensidade: 0.7))

        let luz = SCNLight()
        luz.type = .omni
        luz.color = Paleta.ouro
        luz.intensity = 4000
        luz.attenuationStartDistance = 0
        luz.attenuationEndDistance = 9
        no.light = luz

        let onda = SCNNode(geometry: lib.onda)
        onda.scale = SCNVector3(0.2, 0.2, 0.2)
        no.addChildNode(onda)
        onda.runAction(.group([.scale(to: 7, duration: 0.9), .fadeOut(duration: 0.9)]))

        efeitos.addChildNode(no)
        let apagar = SCNAction.customAction(duration: 0.7) { n, t in
            n.light?.intensity = 4000 * max(0, 1 - t / 0.7)
        }
        no.runAction(.sequence([apagar, .wait(duration: 1.6), .removeFromParentNode()]))
    }

    private func poeira(em v: SCNVector3) {
        let no = SCNNode()
        no.position = SCNVector3(v.x, 0.4, v.z)
        no.addParticleSystem(Efeitos.explosao(cor: Paleta.brasa, intensidade: 0.35))
        efeitos.addChildNode(no)
        no.runAction(.sequence([.wait(duration: 1.5), .removeFromParentNode()]))
    }

    private func tremerCamera() {
        var passos: [SCNAction] = []
        for _ in 0..<6 {
            let dx = CGFloat.random(in: -0.3...0.3)
            let dy = CGFloat.random(in: -0.22...0.22)
            passos.append(.moveBy(x: dx, y: dy, z: 0, duration: 0.04))
            passos.append(.moveBy(x: -dx, y: -dy, z: 0, duration: 0.04))
        }
        cameraNo.runAction(.sequence(passos), forKey: "tremor")
    }

    // MARK: - Câmera

    private func posicionarCamera(animado: Bool) {
        cameraNo.removeAction(forKey: "tremor")
        let modo = modoCamera ?? .orbital

        if modo == .perseguicao {
            predador.no.addChildNode(cameraNo)
            cameraNo.position = SCNVector3(0, 2.8, -4.6)
            let frente = predador.no.convertPosition(SCNVector3(0, 0, 3.2), to: nil)
            cameraNo.look(at: frente)
            return
        }

        if cameraNo.parent !== cena.rootNode {
            let t = cameraNo.worldTransform
            cena.rootNode.addChildNode(cameraNo)
            cameraNo.transform = t
        }

        let p: CGFloat = modo == .tatica ? 1.5 : pitch
        let y: CGFloat = modo == .tatica ? 0 : yaw
        let d = CGFloat(max(linhas, colunas)) * 1.02 * zoom + 4
        let destino = SCNVector3(d * cos(p) * sin(y), d * sin(p), d * cos(p) * cos(y))

        SCNTransaction.begin()
        SCNTransaction.animationDuration = animado ? 0.9 : 0
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cameraNo.position = destino
        cameraNo.look(at: SCNVector3(0, 0, 0))
        SCNTransaction.commit()
    }

    // MARK: - Interação

    @MainActor
    func tocar(_ p: Pos, comeco: Bool, jogo: JogoModel) {
        guard jogo.grade.contem(p) else { return }
        if comeco || arrasto == nil {
            if jogo.fase.ativa && jogo.duelo == nil {
                // Sabotagem ao vivo: altera o setor sem parar a caçada.
                arrasto = .pintura
            } else {
                jogo.prepararEdicao()
                if p == jogo.inicio { arrasto = .inicio }
                else if p == jogo.alvo { arrasto = .alvo }
                else { arrasto = .pintura }
            }
        }
        switch arrasto {
        case .inicio:  jogo.moverInicio(para: p)
        case .alvo:    jogo.moverAlvo(para: p)
        case .pintura: jogo.pintar(em: p)
        case .none:    break
        }
    }

    func soltar() {
        arrasto = nil
    }

    @MainActor
    func orbitar(dx: CGFloat, dy: CGFloat, jogo: JogoModel) {
        if jogo.camera != .orbital {
            if jogo.camera == .tatica {
                yaw = 0
                pitch = 1.45
            }
            modoCamera = .orbital
            jogo.camera = .orbital
        }
        yaw -= dx * 0.008
        pitch = min(1.48, max(0.25, pitch + dy * 0.006))
        posicionarCamera(animado: false)
    }

    func aplicarZoom(_ delta: CGFloat) {
        zoom = min(2.2, max(0.35, zoom * (1 - delta)))
        if modoCamera != .perseguicao {
            posicionarCamera(animado: false)
        }
    }

    func destacar(_ p: Pos?) {
        guard let p else {
            cursorNo.isHidden = true
            return
        }
        var v = mundoPos(p)
        v.y = 0.1
        cursorNo.position = v
        cursorNo.isHidden = false
    }
}
