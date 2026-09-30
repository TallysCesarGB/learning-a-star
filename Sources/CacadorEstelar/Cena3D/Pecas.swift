import AppKit
import SceneKit

// MARK: - Materiais

enum Materiais {
    static func metal(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat,
                      metalico: CGFloat = 0.85, rugosidade: CGFloat = 0.3) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
        m.metalness.contents = metalico
        m.roughness.contents = rugosidade
        return m
    }

    /// Material que "emite luz": ignora iluminação e dispara o bloom da câmera.
    static func brilho(_ cor: NSColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = cor
        return m
    }

    static func holograma(_ imagem: NSImage, aditivo: Bool = false) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = imagem
        m.isDoubleSided = true
        m.writesToDepthBuffer = false
        m.blendMode = aditivo ? .add : .alpha
        return m
    }

    static let invisivel: SCNMaterial = {
        let m = SCNMaterial()
        m.transparency = 0
        m.writesToDepthBuffer = false
        return m
    }()
}

// MARK: - Naves

struct Nave {
    let no: SCNNode
    let brilho: SCNMaterial
    let rastro: SCNParticleSystem

    func colorir(_ cor: NSColor) {
        brilho.diffuse.contents = cor
        rastro.particleColor = cor
    }
}

enum Naves {

    private static func flutuar(_ no: SCNNode, amplitude: CGFloat = 0.07, periodo: TimeInterval = 1.3) {
        let sobe = SCNAction.moveBy(x: 0, y: amplitude, z: 0, duration: periodo)
        sobe.timingMode = .easeInEaseOut
        let desce = SCNAction.moveBy(x: 0, y: -amplitude, z: 0, duration: periodo)
        desce.timingMode = .easeInEaseOut
        no.runAction(.repeatForever(.sequence([sobe, desce])))
    }

    static func rastroMotor(cor: NSColor, tamanho: CGFloat = 0.13) -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = 140
        p.particleLifeSpan = 0.5
        p.particleLifeSpanVariation = 0.15
        p.emitterShape = SCNSphere(radius: 0.03)
        p.particleSize = tamanho
        p.particleSizeVariation = tamanho * 0.3
        p.particleColor = cor
        p.particleImage = Texturas.particula
        p.blendMode = .additive
        p.particleVelocity = 0.25
        p.spreadingAngle = 12
        p.emittingDirection = SCNVector3(0, 0, -1)
        p.isAffectedByGravity = false
        p.isLightingEnabled = false
        p.loops = true
        let encolher = CAKeyframeAnimation()
        encolher.values = [1.0, 0.0]
        encolher.keyTimes = [0, 1]
        p.propertyControllers = [.size: SCNParticlePropertyController(animation: encolher)]
        return p
    }

    /// Caça interceptador: fuselagem em flecha, asas enflechadas com faixa de neon e aletas.
    /// A frente da nave aponta para +Z.
    static func interceptador(cor: NSColor) -> Nave {
        let raiz = SCNNode()
        let casco = SCNNode()
        raiz.addChildNode(casco)

        let claro = Materiais.metal(0.80, 0.82, 0.86)
        let escuro = Materiais.metal(0.12, 0.13, 0.16, metalico: 0.6, rugosidade: 0.4)
        let vidro = Materiais.metal(0.05, 0.08, 0.14, metalico: 0.9, rugosidade: 0.05)
        let glow = Materiais.brilho(cor)

        let fuselagem = SCNPyramid(width: 0.36, height: 1.1, length: 0.2)
        fuselagem.materials = [claro]
        let fn = SCNNode(geometry: fuselagem)
        fn.eulerAngles.x = .pi / 2
        fn.position = SCNVector3(0, 0, -0.48)
        casco.addChildNode(fn)

        let dorso = SCNBox(width: 0.2, height: 0.12, length: 0.55, chamferRadius: 0.05)
        dorso.materials = [escuro]
        let dn = SCNNode(geometry: dorso)
        dn.position = SCNVector3(0, 0.05, -0.2)
        casco.addChildNode(dn)

        let cabine = SCNSphere(radius: 0.1)
        cabine.materials = [vidro]
        let cn = SCNNode(geometry: cabine)
        cn.scale = SCNVector3(0.8, 0.6, 1.9)
        cn.position = SCNVector3(0, 0.1, 0.08)
        casco.addChildNode(cn)

        for lado in [CGFloat(-1), CGFloat(1)] {
            let asa = SCNBox(width: 0.64, height: 0.035, length: 0.36, chamferRadius: 0.015)
            asa.materials = [claro]
            let an = SCNNode(geometry: asa)
            an.position = SCNVector3(lado * 0.34, -0.02, -0.3)
            an.eulerAngles.y = lado * 0.45
            an.eulerAngles.z = lado * 0.07
            casco.addChildNode(an)

            let faixa = SCNBox(width: 0.6, height: 0.022, length: 0.035, chamferRadius: 0)
            faixa.materials = [glow]
            let fx = SCNNode(geometry: faixa)
            fx.position = SCNVector3(0, 0.02, 0.17)
            an.addChildNode(fx)

            let aleta = SCNBox(width: 0.03, height: 0.28, length: 0.26, chamferRadius: 0.01)
            aleta.materials = [escuro]
            let al = SCNNode(geometry: aleta)
            al.position = SCNVector3(lado * 0.3, 0.11, -0.06)
            an.addChildNode(al)
        }

        let bocal = SCNCylinder(radius: 0.1, height: 0.14)
        bocal.materials = [escuro]
        let bn = SCNNode(geometry: bocal)
        bn.eulerAngles.x = .pi / 2
        bn.position = SCNVector3(0, 0.02, -0.52)
        casco.addChildNode(bn)

        let chama = SCNSphere(radius: 0.08)
        chama.materials = [glow]
        let ch = SCNNode(geometry: chama)
        ch.position = SCNVector3(0, 0.02, -0.6)
        casco.addChildNode(ch)

        let rastro = rastroMotor(cor: cor)
        let emissor = SCNNode()
        emissor.position = SCNVector3(0, 0.02, -0.66)
        emissor.addParticleSystem(rastro)
        casco.addChildNode(emissor)

        raiz.scale = SCNVector3(0.9, 0.9, 0.9)
        flutuar(casco)
        return Nave(no: raiz, brilho: glow, rastro: rastro)
    }

    /// Nave mensageira: casco em cápsula com dois módulos orbitando o eixo.
    static func mensageiro() -> Nave {
        let raiz = SCNNode()
        let casco = SCNNode()
        raiz.addChildNode(casco)

        let perola = Materiais.metal(0.92, 0.93, 0.96, metalico: 0.35, rugosidade: 0.22)
        let glow = Materiais.brilho(Paleta.verde)

        let corpo = SCNCapsule(capRadius: 0.16, height: 0.72)
        corpo.materials = [perola]
        let cn = SCNNode(geometry: corpo)
        cn.eulerAngles.x = .pi / 2
        casco.addChildNode(cn)

        let anel = SCNTorus(ringRadius: 0.3, pipeRadius: 0.025)
        anel.materials = [glow]
        let an = SCNNode(geometry: anel)
        an.eulerAngles.x = .pi / 2
        casco.addChildNode(an)

        let giro = SCNNode()
        casco.addChildNode(giro)
        for lado in [CGFloat(-1), CGFloat(1)] {
            let modulo = SCNSphere(radius: 0.07)
            modulo.materials = [glow]
            let mn = SCNNode(geometry: modulo)
            mn.position = SCNVector3(lado * 0.3, 0, 0)
            giro.addChildNode(mn)
        }
        giro.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: .pi * 2, duration: 2.4)))

        let chama = SCNSphere(radius: 0.07)
        chama.materials = [glow]
        let ch = SCNNode(geometry: chama)
        ch.position = SCNVector3(0, 0, -0.42)
        casco.addChildNode(ch)

        let rastro = rastroMotor(cor: Paleta.verde, tamanho: 0.1)
        let emissor = SCNNode()
        emissor.position = SCNVector3(0, 0, -0.48)
        emissor.addParticleSystem(rastro)
        casco.addChildNode(emissor)

        raiz.scale = SCNVector3(0.9, 0.9, 0.9)
        flutuar(casco, amplitude: 0.09, periodo: 1.0)
        return Nave(no: raiz, brilho: glow, rastro: rastro)
    }

    /// Feixe de luz vertical com a letra do ponto (A ou B) flutuando no topo.
    static func farol(cor: NSColor, letra: String) -> SCNNode {
        let raiz = SCNNode()

        let feixe = SCNCylinder(radius: 0.42, height: 3.2)
        feixe.materials = [Materiais.holograma(Texturas.gradienteFarol(cor: cor), aditivo: true),
                           Materiais.invisivel, Materiais.invisivel]
        let fn = SCNNode(geometry: feixe)
        fn.position = SCNVector3(0, 1.6, 0)
        fn.castsShadow = false
        raiz.addChildNode(fn)

        let base = SCNTorus(ringRadius: 0.46, pipeRadius: 0.03)
        base.materials = [Materiais.brilho(cor)]
        let bn = SCNNode(geometry: base)
        bn.position = SCNVector3(0, 0.1, 0)
        raiz.addChildNode(bn)
        let pulso = SCNAction.sequence([.scale(to: 1.15, duration: 0.8), .scale(to: 1.0, duration: 0.8)])
        bn.runAction(.repeatForever(pulso))

        let texto = SCNText(string: letra, extrusionDepth: 0.05)
        texto.font = NSFont.systemFont(ofSize: 0.9, weight: .black)
        texto.flatness = 0.01
        texto.materials = [Materiais.brilho(cor)]
        let tn = SCNNode(geometry: texto)
        let (mn, mx) = tn.boundingBox
        tn.pivot = SCNMatrix4MakeTranslation((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, 0)
        let suporte = SCNNode()
        suporte.position = SCNVector3(0, 3.5, 0)
        suporte.constraints = [SCNBillboardConstraint()]
        suporte.addChildNode(tn)
        raiz.addChildNode(suporte)
        flutuar(suporte, amplitude: 0.15, periodo: 1.6)

        return raiz
    }
}

// MARK: - Efeitos

enum Efeitos {
    static func explosao(cor: NSColor, intensidade: CGFloat = 1) -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = 2600 * intensidade
        p.emissionDuration = 0.08
        p.loops = false
        p.particleLifeSpan = 0.9
        p.particleLifeSpanVariation = 0.4
        p.particleVelocity = 3.2 * intensidade
        p.particleVelocityVariation = 2.0 * intensidade
        p.spreadingAngle = 180
        p.emitterShape = SCNSphere(radius: 0.1)
        p.particleSize = 0.14
        p.particleSizeVariation = 0.06
        p.particleImage = Texturas.particula
        p.particleColor = cor
        p.blendMode = .additive
        p.isAffectedByGravity = false
        p.isLightingEnabled = false
        p.dampingFactor = 1.6
        let encolher = CAKeyframeAnimation()
        encolher.values = [1.0, 0.0]
        encolher.keyTimes = [0, 1]
        p.propertyControllers = [.size: SCNParticlePropertyController(animation: encolher)]
        return p
    }
}

// MARK: - Biblioteca de geometrias compartilhadas

/// Geometrias e materiais são criados uma vez e reaproveitados por milhares de nós.
final class Biblioteca {
    private var placas: [Terreno: SCNGeometry] = [:]
    private var exploradas: [Algoritmo: SCNGeometry] = [:]
    private var meias: [Algoritmo: SCNGeometry] = [:]
    private var lasers: [Algoritmo: SCNGeometry] = [:]
    private var pontos: [Algoritmo: SCNGeometry] = [:]

    let nuvem: SCNGeometry
    let fragmento: SCNGeometry
    let anelTempestade: SCNGeometry
    let rochas: [SCNGeometry]
    let aro: SCNGeometry
    let pontoRastro: SCNGeometry
    let cursor: SCNGeometry
    let onda: SCNGeometry

    init() {
        let n = SCNSphere(radius: 0.55)
        n.segmentCount = 16
        let nm = SCNMaterial()
        nm.lightingModel = .constant
        nm.diffuse.contents = Paleta.violeta.withAlphaComponent(0.22)
        nm.blendMode = .add
        nm.writesToDepthBuffer = false
        n.materials = [nm]
        nuvem = n

        let f = SCNBox(width: 0.16, height: 0.06, length: 0.12, chamferRadius: 0.015)
        f.materials = [Materiais.metal(0.55, 0.48, 0.40, metalico: 0.7, rugosidade: 0.55)]
        fragmento = f

        let t = SCNTorus(ringRadius: 0.28, pipeRadius: 0.02)
        t.materials = [Materiais.brilho(Paleta.magenta)]
        anelTempestade = t

        rochas = (0..<5).map { _ in Rochas.gerar() }

        let a = SCNTorus(ringRadius: 0.3, pipeRadius: 0.028)
        a.materials = [Materiais.brilho(Paleta.ouro)]
        aro = a

        let pr = SCNSphere(radius: 0.05)
        pr.materials = [Materiais.brilho(NSColor(white: 1, alpha: 0.7))]
        pontoRastro = pr

        let c = SCNPlane(width: 1.05, height: 1.05)
        c.materials = [Materiais.holograma(Texturas.cursor(), aditivo: true)]
        cursor = c

        let o = SCNTorus(ringRadius: 0.5, pipeRadius: 0.04)
        o.materials = [Materiais.brilho(Paleta.verde)]
        onda = o
    }

    func placa(_ t: Terreno) -> SCNGeometry {
        if let g = placas[t] { return g }
        let box = SCNBox(width: 0.94, height: 0.14, length: 0.94, chamferRadius: 0.06)
        box.chamferSegmentCount = 2
        let m: SCNMaterial
        switch t {
        case .rota:
            m = Materiais.metal(0.05, 0.12, 0.16, metalico: 0.7, rugosidade: 0.3)
            m.emission.contents = Texturas.bordaPlaca(cor: Paleta.ciano, forca: 1.0, duplo: true)
            m.emission.intensity = 1.3
        case .vacuo:
            m = Materiais.metal(0.10, 0.12, 0.17, metalico: 0.85, rugosidade: 0.35)
            m.emission.contents = Texturas.bordaPlaca(cor: NSColor(srgbRed: 0.35, green: 0.5, blue: 0.9, alpha: 1), forca: 0.35)
        case .nebulosa:
            m = Materiais.metal(0.14, 0.08, 0.22, metalico: 0.6, rugosidade: 0.4)
            m.emission.contents = Texturas.bordaPlaca(cor: Paleta.violeta, forca: 0.6)
        case .detritos:
            m = Materiais.metal(0.22, 0.18, 0.14, metalico: 0.5, rugosidade: 0.8)
            m.emission.contents = Texturas.bordaPlaca(cor: Paleta.ouro, forca: 0.3)
        case .tempestade:
            m = Materiais.metal(0.20, 0.05, 0.12, metalico: 0.6, rugosidade: 0.4)
            m.emission.contents = Texturas.bordaPlaca(cor: Paleta.magenta, forca: 0.9)
            let pulso = CABasicAnimation(keyPath: "emission.intensity")
            pulso.fromValue = 0.3
            pulso.toValue = 1.5
            pulso.duration = 0.8
            pulso.autoreverses = true
            pulso.repeatCount = .infinity
            m.addAnimation(pulso, forKey: "pulso")
        case .asteroide:
            m = Materiais.metal(0.07, 0.07, 0.08, metalico: 0.3, rugosidade: 0.9)
        }
        box.materials = [m]
        placas[t] = box
        return box
    }

    /// Decoração 3D sobre a placa. Cada chamada cria um nó novo com geometria compartilhada.
    func decoracao(_ t: Terreno) -> SCNNode? {
        switch t {
        case .rota, .vacuo:
            return nil
        case .nebulosa:
            let n = SCNNode()
            for _ in 0..<2 {
                let s = SCNNode(geometry: nuvem)
                let k = CGFloat.random(in: 0.7...1.1)
                s.scale = SCNVector3(k, k * 0.45, k)
                s.position = SCNVector3(CGFloat.random(in: -0.15...0.15), 0.3, CGFloat.random(in: -0.15...0.15))
                s.castsShadow = false
                n.addChildNode(s)
            }
            return n
        case .detritos:
            let n = SCNNode()
            for _ in 0..<3 {
                let s = SCNNode(geometry: fragmento)
                s.position = SCNVector3(CGFloat.random(in: -0.3...0.3), CGFloat.random(in: 0.14...0.3), CGFloat.random(in: -0.3...0.3))
                s.eulerAngles = SCNVector3(CGFloat.random(in: 0...3), CGFloat.random(in: 0...3), CGFloat.random(in: 0...3))
                n.addChildNode(s)
            }
            return n
        case .tempestade:
            let s = SCNNode(geometry: anelTempestade)
            s.position = SCNVector3(0, 0.26, 0)
            s.eulerAngles = SCNVector3(CGFloat.random(in: -0.3...0.3), 0, CGFloat.random(in: -0.3...0.3))
            s.castsShadow = false
            return s
        case .asteroide:
            let s = SCNNode(geometry: rochas.randomElement()!)
            let k = CGFloat.random(in: 0.40...0.52)
            s.scale = SCNVector3(k, k * CGFloat.random(in: 0.75...0.95), k)
            s.eulerAngles = SCNVector3(CGFloat.random(in: 0...6.28), CGFloat.random(in: 0...6.28), CGFloat.random(in: 0...6.28))
            s.position = SCNVector3(0, 0.36, 0)
            return s
        }
    }

    func explorada(_ a: Algoritmo) -> SCNGeometry {
        if let g = exploradas[a] { return g }
        let p = SCNPlane(width: 0.9, height: 0.9)
        p.materials = [Materiais.holograma(Texturas.azulejoHolo(cor: a.nsCor))]
        exploradas[a] = p
        return p
    }

    func meia(_ a: Algoritmo) -> SCNGeometry {
        if let g = meias[a] { return g }
        let p = SCNPlane(width: 0.42, height: 0.42)
        p.materials = [Materiais.holograma(Texturas.azulejoHolo(cor: a.nsCor, alphaFundo: 0.5))]
        meias[a] = p
        return p
    }

    func laser(_ a: Algoritmo) -> SCNGeometry {
        if let g = lasers[a] { return g }
        let c = SCNCylinder(radius: 0.05, height: 1)
        c.radialSegmentCount = 10
        c.materials = [Materiais.brilho(a.nsCor)]
        lasers[a] = c
        return c
    }

    func ponto(_ a: Algoritmo) -> SCNGeometry {
        if let g = pontos[a] { return g }
        let s = SCNSphere(radius: 0.1)
        s.segmentCount = 12
        s.materials = [Materiais.brilho(a.nsCor.blended(withFraction: 0.5, of: .white) ?? a.nsCor)]
        pontos[a] = s
        return s
    }
}
