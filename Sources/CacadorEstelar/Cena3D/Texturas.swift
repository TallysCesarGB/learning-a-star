import AppKit
import SceneKit
import simd

/// Todas as texturas são desenhadas por código: nenhum arquivo de imagem é necessário.
enum Texturas {

    private static let espaco = CGColorSpace(name: CGColorSpace.sRGB)!

    static func criar(_ largura: Int, _ altura: Int, _ desenho: (CGContext, CGFloat, CGFloat) -> Void) -> NSImage {
        guard let ctx = CGContext(data: nil, width: largura, height: altura, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: espaco,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return NSImage()
        }
        desenho(ctx, CGFloat(largura), CGFloat(altura))
        guard let img = ctx.makeImage() else { return NSImage() }
        return NSImage(cgImage: img, size: NSSize(width: largura, height: altura))
    }

    private static func gradiente(_ cores: [CGColor]) -> CGGradient {
        let locais: [CGFloat] = cores.count == 2 ? [0, 1] : (0..<cores.count).map { CGFloat($0) / CGFloat(cores.count - 1) }
        return CGGradient(colorsSpace: espaco, colors: cores as CFArray, locations: locais)!
    }

    /// Céu equiretangular (2:1): o SceneKit o projeta como uma esfera ao redor da cena.
    static func ceuEstrelado() -> NSImage {
        criar(2048, 1024) { ctx, w, h in
            ctx.setFillColor(CGColor(srgbRed: 0.006, green: 0.010, blue: 0.026, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

            let tons: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (0.36, 0.12, 0.58, 0.30), (0.05, 0.24, 0.52, 0.28),
                (0.62, 0.14, 0.26, 0.18), (0.10, 0.40, 0.46, 0.16)
            ]
            for _ in 0..<9 {
                let t = tons.randomElement()!
                let cor = CGColor(srgbRed: t.0, green: t.1, blue: t.2, alpha: t.3)
                let centro = CGPoint(x: CGFloat.random(in: 0...w), y: CGFloat.random(in: (h * 0.25)...(h * 0.75)))
                let raio = CGFloat.random(in: 140...460)
                ctx.drawRadialGradient(gradiente([cor, cor.copy(alpha: 0)!]),
                                       startCenter: centro, startRadius: 0,
                                       endCenter: centro, endRadius: raio, options: [])
            }

            for _ in 0..<3600 {
                let x = CGFloat.random(in: 0...w)
                let y = CGFloat.random(in: 0...h)
                let grande = CGFloat.random(in: 0...1) > 0.975
                let s = grande ? CGFloat.random(in: 1.8...3.4) : CGFloat.random(in: 0.5...1.5)
                let b = CGFloat.random(in: 0.4...1)
                let cor: CGColor
                switch Int.random(in: 0..<10) {
                case 0:  cor = CGColor(srgbRed: 0.7 * b, green: 0.82 * b, blue: b, alpha: 1)
                case 1:  cor = CGColor(srgbRed: b, green: 0.86 * b, blue: 0.68 * b, alpha: 1)
                default: cor = CGColor(gray: b, alpha: 1)
                }
                if grande {
                    ctx.drawRadialGradient(gradiente([cor.copy(alpha: 0.5)!, cor.copy(alpha: 0)!]),
                                           startCenter: CGPoint(x: x, y: y), startRadius: 0,
                                           endCenter: CGPoint(x: x, y: y), endRadius: s * 3, options: [])
                }
                ctx.setFillColor(cor)
                ctx.fillEllipse(in: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s))
            }
        }
    }

    /// Emissão da placa: bordas de neon sobre fundo preto (preto = não emite).
    static func bordaPlaca(cor: NSColor, forca: CGFloat, duplo: Bool = false) -> NSImage {
        criar(256, 256) { ctx, w, h in
            ctx.setFillColor(CGColor(gray: 0, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            let base = cor.cgColor
            for k in 0..<7 {
                let inset = CGFloat(8 + k * 3)
                let alpha = forca * (1 - CGFloat(k) / 7)
                ctx.setStrokeColor(base.copy(alpha: max(0, min(1, alpha)))!)
                ctx.setLineWidth(3)
                let r = CGRect(x: inset, y: inset, width: w - 2 * inset, height: h - 2 * inset)
                ctx.addPath(CGPath(roundedRect: r, cornerWidth: 22, cornerHeight: 22, transform: nil))
                ctx.strokePath()
            }
            if duplo {
                ctx.setStrokeColor(base.copy(alpha: forca * 0.55)!)
                ctx.setLineWidth(4)
                let r = CGRect(x: 70, y: 70, width: w - 140, height: h - 140)
                ctx.addPath(CGPath(roundedRect: r, cornerWidth: 12, cornerHeight: 12, transform: nil))
                ctx.strokePath()
            }
        }
    }

    /// Azulejo holográfico translúcido para nós explorados.
    static func azulejoHolo(cor: NSColor, alphaFundo: CGFloat = 0.30) -> NSImage {
        criar(128, 128) { ctx, w, h in
            ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
            let c = cor.cgColor
            let r = CGRect(x: 8, y: 8, width: w - 16, height: h - 16)
            let caminho = CGPath(roundedRect: r, cornerWidth: 14, cornerHeight: 14, transform: nil)
            ctx.addPath(caminho)
            ctx.setFillColor(c.copy(alpha: alphaFundo)!)
            ctx.fillPath()
            ctx.addPath(caminho)
            ctx.setStrokeColor(c.copy(alpha: 0.95)!)
            ctx.setLineWidth(4)
            ctx.strokePath()
        }
    }

    /// Moldura de mira (cantoneiras). Branca no cursor de seleção, colorida no ponto previsto.
    static func cursor(cor: NSColor = .white) -> NSImage {
        criar(128, 128) { ctx, w, h in
            ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.setStrokeColor(cor.cgColor)
            ctx.setLineWidth(6)
            let t: CGFloat = 34
            let m: CGFloat = 6
            let cantos: [[CGPoint]] = [
                [CGPoint(x: m, y: m + t), CGPoint(x: m, y: m), CGPoint(x: m + t, y: m)],
                [CGPoint(x: w - m - t, y: m), CGPoint(x: w - m, y: m), CGPoint(x: w - m, y: m + t)],
                [CGPoint(x: w - m, y: h - m - t), CGPoint(x: w - m, y: h - m), CGPoint(x: w - m - t, y: h - m)],
                [CGPoint(x: m + t, y: h - m), CGPoint(x: m, y: h - m), CGPoint(x: m, y: h - m - t)]
            ]
            for canto in cantos {
                ctx.addLines(between: canto)
                ctx.strokePath()
            }
        }
    }

    /// Grade fina para a base holográfica sob o setor.
    static func gradeHolo() -> NSImage {
        criar(128, 128) { ctx, w, h in
            ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.setStrokeColor(Paleta.ciano.cgColor.copy(alpha: 0.22)!)
            ctx.setLineWidth(2)
            ctx.stroke(CGRect(x: 1, y: 1, width: w - 2, height: h - 2))
            ctx.setFillColor(Paleta.ciano.cgColor.copy(alpha: 0.5)!)
            ctx.fillEllipse(in: CGRect(x: -3, y: -3, width: 6, height: 6))
        }
    }

    /// Gradiente vertical para os feixes de luz dos faróis A e B.
    static func gradienteFarol(cor: NSColor) -> NSImage {
        criar(16, 256) { ctx, w, h in
            ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
            let c = cor.cgColor
            ctx.drawLinearGradient(gradiente([c.copy(alpha: 0.8)!, c.copy(alpha: 0.25)!, c.copy(alpha: 0)!]),
                                   start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: h), options: [])
        }
    }

    /// Ponto luminoso usado pelas partículas.
    static let particula: NSImage = criar(64, 64) { ctx, w, h in
        ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
        let centro = CGPoint(x: w / 2, y: h / 2)
        ctx.drawRadialGradient(gradiente([CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0.35), CGColor(gray: 1, alpha: 0)]),
                               startCenter: centro, startRadius: 0,
                               endCenter: centro, endRadius: w / 2, options: [])
    }
}

/// Asteroides low-poly: icosaedro subdividido, vértices deslocados e normais por face (visual facetado).
enum Rochas {

    static func gerar() -> SCNGeometry {
        let t = (1 + 5.0.squareRoot()) / 2
        let bruto: [SIMD3<Double>] = [
            SIMD3(-1, t, 0), SIMD3(1, t, 0), SIMD3(-1, -t, 0), SIMD3(1, -t, 0),
            SIMD3(0, -1, t), SIMD3(0, 1, t), SIMD3(0, -1, -t), SIMD3(0, 1, -t),
            SIMD3(t, 0, -1), SIMD3(t, 0, 1), SIMD3(-t, 0, -1), SIMD3(-t, 0, 1)
        ]
        var v: [SIMD3<Double>] = bruto.map { simd_normalize($0) }

        var faces: [(Int, Int, Int)] = [
            (0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11),
            (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
            (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9),
            (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)
        ]

        // Uma subdivisão (20 -> 80 faces), reaproveitando pontos médios.
        var cache: [Int: Int] = [:]
        func meio(_ a: Int, _ b: Int) -> Int {
            let chave = min(a, b) * 1000 + max(a, b)
            if let i = cache[chave] { return i }
            v.append(simd_normalize((v[a] + v[b]) / 2))
            cache[chave] = v.count - 1
            return v.count - 1
        }
        var novas: [(Int, Int, Int)] = []
        for (a, b, c) in faces {
            let ab = meio(a, b), bc = meio(b, c), ca = meio(c, a)
            novas += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        }
        faces = novas

        // Deslocamento aleatório dos vértices: cada rocha fica única.
        v = v.map { $0 * Double.random(in: 0.74...1.12) }

        var vertices: [SCNVector3] = []
        var normais: [SCNVector3] = []
        var indices: [Int32] = []
        for (ia, ib, ic) in faces {
            let a = v[ia]
            var b = v[ib], c = v[ic]
            var n = simd_normalize(simd_cross(b - a, c - a))
            if simd_dot(n, (a + b + c) / 3) < 0 {
                swap(&b, &c)
                n = -n
            }
            for p in [a, b, c] {
                indices.append(Int32(vertices.count))
                vertices.append(SCNVector3(CGFloat(p.x), CGFloat(p.y), CGFloat(p.z)))
                normais.append(SCNVector3(CGFloat(n.x), CGFloat(n.y), CGFloat(n.z)))
            }
        }

        let geo = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices),
                                        SCNGeometrySource(normals: normais)],
                              elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = NSColor(srgbRed: 0.36, green: 0.32, blue: 0.29, alpha: 1)
        m.roughness.contents = 0.92
        m.metalness.contents = 0.12
        geo.materials = [m]
        return geo
    }
}
