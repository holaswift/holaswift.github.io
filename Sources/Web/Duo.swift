// iPhone Duo: Safari deja una franja de controles a la derecha y solo muestra en ella contenido real del documento.
// Se cuelga una columna del body justo donde acaba la ventana y se reconstruye ahí el fondo de cada sección (con la
// retícula de puntos del hero, la esquina redondeada del manifiesto y el velo de la hoja que esté abierta).
// En cualquier otro dispositivo no hace nada.

import HolaSwift
import JavaScriptKit

func contiene(_ t: String, _ trozo: String) -> Bool {
    let a = Array(t.unicodeScalars), b = Array(trozo.unicodeScalars)
    guard !b.isEmpty, a.count >= b.count else { return b.isEmpty }
    for i in 0...(a.count - b.count) where Array(a[i..<(i + b.count)]) == b { return true }
    return false
}

func numerosDeColor(_ t: String) -> [Double] {
    var numeros: [Double] = [], actual = ""
    func cerrar() { if !actual.isEmpty { numeros.append(decimal(.string(actual))); actual = "" } }
    for c in t.unicodeScalars {
        if (c >= "0" && c <= "9") || c == "." { actual.unicodeScalars.append(c) } else { cerrar() }
    }
    cerrar()
    return numeros
}

func px(_ x: Double) -> String { numeroJS(x) + "px" }

let selectorCapaAbierta = ".capa-carta.abierta, .patro-capa.abierta, .cal-capa.abierta, .ficha-capa.abierta"
let selectorVelo = ".capa-fondo, .patro-fondo, .cal-fondo, .ficha-fondo"

func prepararDuo() {
    func franja() -> Double {
        guard contiene(global.navigator.userAgent.string ?? "", "iPhone"), decimal(global.navigator.maxTouchPoints) >= 2 else { return 0 }
        let g = (decimal(global.screen.width) - decimal(global.innerWidth)).rounded()
        return g >= 40 && g <= 200 ? g : 0
    }
    var borde: JSValue? = nil, firma = ""
    let raiz = document.documentElement, cuerpo = document.body

    func quitar() {
        guard let b = borde else { return }
        _ = b.remove(); borde = nil; firma = ""
        for e in lista(document.querySelectorAll("[data-radio-derecho]")) { e.style.borderTopRightRadius = ""; _ = e.removeAttribute("data-radio-derecho") }
        raiz.style.touchAction = ""; cuerpo.style.touchAction = ""
        raiz.style.overflowX = ""; cuerpo.style.overflowX = ""
    }

    func hacer() {
        let b = franja()
        guard b > 0 else { quitar(); return }
        let ancho = decimal(global.innerWidth), alto = decimal(raiz.scrollHeight), desplazado = decimal(global.scrollY)
        let hero = porId("hero")
        let secciones = ([hero] + lista(document.querySelectorAll("main > section")) + [document.querySelector("footer")]).filter { $0.object != nil }
        let medidas = secciones.map { e -> (Int, Int) in let r = Caja(e); return (Int((r.top + desplazado).rounded()), Int(r.height.rounded())) }
        let reticula: JSValue = hero.object != nil ? global.getComputedStyle(hero, "::before") : .null
        let capa = document.querySelector(selectorCapaAbierta)
        let velo: JSValue = capa.object != nil ? capa.querySelector(selectorVelo) : .null
        if !mismoTexto(raiz.style.overflowX.string ?? "", "hidden") && !mismoTexto(raiz.style.overflow.string ?? "", "hidden") { raiz.style.overflowX = "hidden" }
        let nueva = [numeroJS(b), numeroJS(ancho), numeroJS(alto), medidas.map { "\($0.0),\($0.1)" }.joined(separator: ";"),
                     reticula.object != nil ? (reticula.opacity.string ?? "") : "", velo.object != nil ? "v\(Int(desplazado.rounded()))" : ""].joined(separator: "|")
        guard !mismoTexto(nueva, firma) else { return }
        firma = nueva
        if borde == nil {
            raiz.style.overflowX = "hidden"
            cuerpo.style.overflowX = "visible"   // el body recorta en horizontal: aquí tiene que dejar salir la columna
            raiz.style.touchAction = "pan-y pinch-zoom"; cuerpo.style.touchAction = "pan-y pinch-zoom"
            let nuevo = document.createElement("div")
            _ = nuevo.setAttribute("aria-hidden", "true")
            _ = cuerpo.appendChild(nuevo)
            borde = nuevo
        }
        guard let columna = borde else { return }
        columna.style.cssText = .string("position:absolute;top:0;left:" + px(ancho) + ";width:" + px(b) + ";height:" + px(alto)
            + ";overflow:clip;pointer-events:none;z-index:0;background:" + (global.getComputedStyle(cuerpo).backgroundColor.string ?? ""))
        _ = columna.replaceChildren()
        for (i, seccion) in secciones.enumerated() {
            let estilo = global.getComputedStyle(seccion), (arriba, altura) = medidas[i]
            let pieza = document.createElement("div")
            pieza.style.cssText = .string("position:absolute;left:0;width:100%;top:\(arriba)px;height:\(altura)px")
            let fondo = estilo.backgroundColor.string ?? "", imagen = estilo.backgroundImage.string ?? "none"
            if !mismoTexto(fondo, "rgba(0, 0, 0, 0)") { pieza.style.backgroundColor = .string(fondo) }
            if !mismoTexto(imagen, "none") { pieza.style.backgroundImage = .string(imagen) }
            let radio = seccion.dataset.radioDerecho.string ?? (estilo.borderTopRightRadius.string ?? "")
            let r = decimal(global.parseFloat(radio))
            if r != 0 { seccion.dataset.radioDerecho = .string(radio); seccion.style.borderTopRightRadius = "0"; pieza.style.borderTopRightRadius = .string(radio) }
            if mismo(seccion, hero) && reticula.object != nil {
                let tamano = reticula.backgroundSize.string ?? "", paso = decimal(global.parseFloat(tamano)) == 0 ? 24 : decimal(global.parseFloat(tamano))
                let x0 = (decimal(seccion.clientWidth) - paso) / 2
                let desfase = ((x0 - ancho).truncatingRemainder(dividingBy: paso) + paso).truncatingRemainder(dividingBy: paso)
                let mascara = reticula.webkitMaskImage.string ?? (reticula.maskImage.string ?? "")
                let puntos = document.createElement("div")
                puntos.style.cssText = .string("position:absolute;inset:0;background-image:" + (reticula.backgroundImage.string ?? "") + ";background-size:" + tamano + ";"
                    + "background-position:" + px(desfase) + " 0;opacity:" + (reticula.opacity.string ?? "") + ";-webkit-mask-image:"
                    + (mascara.isEmpty ? (reticula.maskImage.string ?? "") : mascara) + ";mask-image:" + (reticula.maskImage.string ?? ""))
                _ = pieza.appendChild(puntos)
            }
            _ = columna.appendChild(pieza)
        }
        if velo.object != nil {
            // la ventana emergente es fija y no llega a la franja: su velo se pinta aquí, a la altura de la pantalla
            let v = document.createElement("div")
            v.style.cssText = .string("position:absolute;left:0;width:100%;top:\(Int(desplazado.rounded()) - 200)px;height:"
                + px(decimal(global.screen.height) + 400) + ";z-index:2;background:" + (global.getComputedStyle(velo).backgroundColor.string ?? ""))
            _ = columna.appendChild(v)
        }
    }

    // Con una ventana emergente abierta la página se bloquea (overflow:hidden) y Safari pinta la franja y la zona bajo su barra
    // con el fondo del body: se le da el color del velo sobre la sección que queda debajo, y se devuelve al cerrar
    var tintado = false
    func tinte() {
        let capa = document.querySelector(selectorCapaAbierta)
        let velo: JSValue = capa.object != nil ? capa.querySelector(selectorVelo) : .null
        guard velo.object != nil else {
            if tintado { cuerpo.style.backgroundColor = ""; tintado = false }
            return
        }
        let desplazado = decimal(global.scrollY), medio = desplazado + altoVentana() / 2
        let seccion = lista(document.querySelectorAll("#hero, main > section, footer")).first { e in
            let r = Caja(e); return r.top + desplazado <= medio && r.bottom + desplazado > medio
        }
        var base = numerosDeColor(seccion.map { global.getComputedStyle($0).backgroundColor.string ?? "" } ?? "")
        if base.count >= 4 && base[3] == 0 { base = [247, 247, 247, 1] }
        if base.count < 3 { base = [0, 0, 0] }
        let color = numerosDeColor(global.getComputedStyle(velo).backgroundColor.string ?? "")
        let a = color.count >= 4 ? color[3] : 1
        let mezcla = (0..<3).map { i in Int(((i < color.count ? color[i] : 0) * a + base[i] * (1 - a)).rounded()) }
        cuerpo.style.backgroundColor = .string("rgb(\(mezcla[0]),\(mezcla[1]),\(mezcla[2]))"); tintado = true
    }

    escuchar(global, "load") { _ in hacer() }
    escuchar(global, "resize") { _ in firma = ""; hacer() }
    _ = global.setInterval(closure { _ in tinte(); hacer() }, 200)
    hacer()
}
