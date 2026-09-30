import SwiftUI
import SceneKit

/// SCNView com controles próprios:
/// clique/arraste pinta ou move A e B; botão direito ou ⌥+arraste orbita; rolagem ou pinça dá zoom.
final class VisaoSCN: SCNView {
    var aoTocar: ((CGPoint, Bool) -> Void)?
    var aoSoltar: (() -> Void)?
    var aoOrbitar: ((CGFloat, CGFloat) -> Void)?
    var aoZoom: ((CGFloat) -> Void)?
    var aoPairar: ((CGPoint?) -> Void)?

    private var orbitando = false
    private var rastreio: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let r = rastreio { removeTrackingArea(r) }
        let r = NSTrackingArea(rect: bounds,
                               options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                               owner: self, userInfo: nil)
        addTrackingArea(r)
        rastreio = r
    }

    private func ponto(_ e: NSEvent) -> CGPoint {
        convert(e.locationInWindow, from: nil)
    }

    override func mouseDown(with e: NSEvent) {
        if e.modifierFlags.contains(.option) {
            orbitando = true
        } else {
            aoTocar?(ponto(e), true)
        }
    }

    override func mouseDragged(with e: NSEvent) {
        if orbitando {
            aoOrbitar?(e.deltaX, e.deltaY)
        } else {
            aoTocar?(ponto(e), false)
            aoPairar?(ponto(e))
        }
    }

    override func mouseUp(with e: NSEvent) {
        orbitando = false
        aoSoltar?()
    }

    override func rightMouseDown(with e: NSEvent) {}

    override func rightMouseDragged(with e: NSEvent) {
        aoOrbitar?(e.deltaX, e.deltaY)
    }

    override func scrollWheel(with e: NSEvent) {
        let fator: CGFloat = e.hasPreciseScrollingDeltas ? 0.004 : 0.04
        aoZoom?(e.scrollingDeltaY * fator)
    }

    override func magnify(with e: NSEvent) {
        aoZoom?(e.magnification)
    }

    override func mouseMoved(with e: NSEvent) {
        aoPairar?(ponto(e))
    }

    override func mouseExited(with e: NSEvent) {
        aoPairar?(nil)
    }
}

struct VisaoEspacial: NSViewRepresentable {
    @ObservedObject var jogo: JogoModel

    func makeCoordinator() -> Renderizador {
        Renderizador()
    }

    func makeNSView(context: Context) -> VisaoSCN {
        let vista = VisaoSCN(frame: .zero)
        let r = context.coordinator
        let jogo = self.jogo

        vista.scene = r.cena
        vista.pointOfView = r.cameraNo
        vista.backgroundColor = .black
        vista.antialiasingMode = .multisampling4X
        vista.rendersContinuously = true
        vista.preferredFramesPerSecond = 60
        vista.allowsCameraControl = false

        MainActor.assumeIsolated {
            vista.aoTocar = { [weak vista, weak r] ponto, comeco in
                guard let vista, let r, let p = r.celula(em: ponto, na: vista) else { return }
                r.tocar(p, comeco: comeco, jogo: jogo)
            }
            vista.aoSoltar = { [weak r] in r?.soltar() }
            vista.aoOrbitar = { [weak r] dx, dy in r?.orbitar(dx: dx, dy: dy, jogo: jogo) }
            vista.aoZoom = { [weak r] d in r?.aplicarZoom(d) }
            vista.aoPairar = { [weak vista, weak r] ponto in
                guard let vista, let r else { return }
                r.destacar(ponto.flatMap { r.celula(em: $0, na: vista) })
            }
            r.atualizar(com: jogo)
        }
        return vista
    }

    func updateNSView(_ vista: VisaoSCN, context: Context) {
        let r = context.coordinator
        let jogo = self.jogo
        MainActor.assumeIsolated {
            r.atualizar(com: jogo)
        }
    }
}
