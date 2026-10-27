// El hero: «¡hola {Swift!» se construye como en una mesa de trabajo, la mano saluda, el logo gira un poco con el puntero,
// y con ratón hay una lupa de editor (esqueleto bajo el cursor y selección de cada pieza) y el cursor de Patricia en el corazón.
//
// Cada fotograma solo escribe en la página lo que ha cambiado (redondeado a 4 decimales): cuando el logo termina de
// construirse, solo se mueven la mano y, si se mueve el puntero, el giro y la lupa.

import HolaSwift
import JavaScriptKit
#if canImport(WASILibc)
import WASILibc   // sin, cos, exp: las cuentas de cada fotograma se hacen aquí, sin cruzar a JavaScript
#endif

// MARK: - Curvas

func entre(_ x: Double, _ a: Double, _ b: Double) -> Double { min(b, max(a, x)) }
struct Tramo { let a, b: Double }
func progreso(_ t: Double, _ r: Tramo) -> Double { entre((t - r.a) / (r.b - r.a == 0 ? 1e-3 : r.b - r.a), 0, 1) }
func suave(_ x: Double) -> Double { -(cos(Double.pi * x) - 1) / 2 }
func frenada(_ x: Double) -> Double { let y = 1 - x; return 1 - y * y * y }
func muelle(_ x: Double) -> Double { x <= 0 ? 0 : exp(-6.5 * x) * sin(15 * x) }
func muelleEntrada(_ x: Double) -> Double { x <= 0 ? 0 : 1 - exp(-6 * x) * cos(12 * x) }
func redondo(_ x: Double) -> Double { (x * 10_000).rounded() / 10_000 }

func decimal2(_ x: Double) -> String {
    guard x.isFinite else { return "0.00" }
    let n = Int((x * 100).rounded()), a = n < 0 ? -n : n, c = a % 100
    return (n < 0 ? "-" : "") + "\(a / 100)." + (c < 10 ? "0" : "") + "\(c)"
}

// MARK: - Coreografía

struct Fases { let k: String; let trazo, malla, color: Tramo; let salto: Double? }   // segundos
let fases = [
    Fases(k: "hola", trazo: Tramo(a: 0.55, b: 1.8), malla: Tramo(a: 1.55, b: 2.45), color: Tramo(a: 2.6, b: 3.4), salto: nil),
    Fases(k: "excl", trazo: Tramo(a: 1.6, b: 1.9), malla: Tramo(a: 2.1, b: 2.3), color: Tramo(a: 2.55, b: 2.75), salto: 1.6),
    Fases(k: "swift", trazo: Tramo(a: 1.95, b: 3.15), malla: Tramo(a: 3.0, b: 3.7), color: Tramo(a: 3.85, b: 4.55), salto: nil),
    Fases(k: "brace", trazo: Tramo(a: 2.45, b: 2.46), malla: Tramo(a: 2.45, b: 2.5), color: Tramo(a: 3.35, b: 3.6), salto: 2.45),
    Fases(k: "bang", trazo: Tramo(a: 3.2, b: 3.5), malla: Tramo(a: 3.95, b: 4.2), color: Tramo(a: 4.6, b: 4.85), salto: 3.2),
]
let guiaTrazo = Tramo(a: 0, b: 0.85), guiaVuelta = Tramo(a: 0.95, b: 1.55)
let manoSalta = 4.15, manoSaluda = 4.5, listo = 5.0

/// La construcción va al 85 % del plan (de 5 s a unos 4,25 s); desde que el logo está listo, el tiempo corre normal
/// y la mano saluda a su ritmo. El modo vídeo (__hero.seek) usa el plan tal cual.
let ritmo = 0.85
func tiempoDelPlan(_ t: Double) -> Double { t < listo * ritmo ? t / ritmo : listo + (t - listo * ritmo) }

final class Valor<T> {
    private var ultimo: T? = nil
    private let igual: (T, T) -> Bool, escribir: (T) -> Void
    init(igual: @escaping (T, T) -> Bool, _ escribir: @escaping (T) -> Void) { self.igual = igual; self.escribir = escribir }
    func poner(_ v: T) {
        if let ultimo, igual(ultimo, v) { return }
        ultimo = v; escribir(v)
    }
}
extension Valor where T == Double { convenience init(_ escribir: @escaping (Double) -> Void) { self.init(igual: { $0 == $1 }, escribir) } }
extension Valor where T == Bool { convenience init(_ escribir: @escaping (Bool) -> Void) { self.init(igual: { $0 == $1 }, escribir) } }
/// Los textos se comparan byte a byte: `==` entre String arrastraría las tablas de Unicode.
extension Valor where T == String { convenience init(_ escribir: @escaping (String) -> Void) { self.init(igual: mismoTexto, escribir) } }

final class Trazo {
    let largo: Double
    let desplazamiento: Valor<Double>
    let nodos: [(Double, Valor<Bool>)]
    init(blanco: JSValue, sombra: JSValue, nodos: [JSValue]) {
        largo = decimal(blanco.getTotalLength())
        let guiones = numeroJS(largo) + " " + numeroJS(largo)
        blanco.style.strokeDasharray = .string(guiones); sombra.style.strokeDasharray = .string(guiones)
        desplazamiento = Valor { d in blanco.style.strokeDashoffset = .number(d); sombra.style.strokeDashoffset = .number(d) }
        self.nodos = nodos.map { g in (decimal(g.dataset.f), Valor<Bool> { on in _ = g.classList.toggle("on", on) }) }
    }
}

final class Pieza {
    let fases: Fases, trazos: [Trazo], total: Double
    let puntos: Valor<Bool>, malla: Valor<Double>, color: Valor<Double>, vectorOpacidad: Valor<Double>, mallaOpacidad: Valor<Double>
    let escala: Valor<Double>, visible: Valor<Bool>
    init?(_ fases: Fases) {
        let el = document.querySelector(".el[data-k=\"" + fases.k + "\"]")
        guard el.object != nil else { return nil }
        self.fases = fases
        let blancos = lista(el.querySelectorAll(".over path")), sombras = lista(el.querySelectorAll(".under path"))
        trazos = blancos.indices.map { i in
            Trazo(blanco: blancos[i], sombra: i < sombras.count ? sombras[i] : blancos[i], nodos: lista(el.querySelectorAll(".nodes[data-i=\"\(i)\"] g")))
        }
        total = trazos.reduce(0) { $0 + $1.largo }
        let vec = el.querySelector(".vec"), mesh = el.querySelector(".mesh"), col = el.querySelector(".col")
        let circulos = lista(el.querySelectorAll("circle.dot"))
        puntos = Valor { on in for c in circulos { c.style.opacity = .number(on ? 1 : 0) } }
        malla = Valor { p in _ = mesh.style.setProperty("--p", p) }
        color = Valor { p in _ = col.style.setProperty("--p", p) }
        vectorOpacidad = Valor { o in vec.style.opacity = .number(o) }
        mallaOpacidad = Valor { o in mesh.style.opacity = .number(o) }
        escala = Valor { s in el.style.transform = .string("scale(" + numeroJS(s) + ")") }
        visible = Valor { v in el.style.visibility = .string(v ? "visible" : "hidden") }
    }

    func dibujar(_ f: Double) {
        var hecho = 0.0
        let largo = f * total
        for trazo in trazos {
            let d = min(trazo.largo, max(0, largo - hecho)); hecho += trazo.largo
            // exacto, sin redondear: con el trazo sin empezar tiene que ser justo su largo, o el remate redondo (stroke-linecap)
            // de un guion de una diezmilésima se pinta como un círculo en el punto de salida
            trazo.desplazamiento.poner(trazo.largo - d)
            for (punto, nodo) in trazo.nodos { nodo.poner(d > 0 && d / trazo.largo >= punto - 0.02) }
        }
        puntos.poner(f >= 1)
    }

    func fotograma(_ t: Double) {
        let m = progreso(t, fases.malla), c = progreso(t, fases.color)
        dibujar(suave(progreso(t, fases.trazo)))
        malla.poner(redondo(suave(m))); color.poner(redondo(suave(c)))
        vectorOpacidad.poner(redondo(m >= 1 ? max(0, 1 - (t - fases.malla.b) / 0.3) : 1))
        mallaOpacidad.poner(redondo(c >= 1 ? max(0, 1 - (t - fases.color.b) / 0.3) : 1))
        var s = 1 + 0.06 * muelle(t - fases.malla.b) + 0.08 * muelle(t - fases.color.b)
        if let salto = fases.salto { s *= muelleEntrada(t - salto) }
        escala.poner(redondo(s)); visible.poner(s > 0.001)
    }
}

// MARK: - Lupa del logo

struct Caja2D { let nombre: String; let x, y, w, h: Double }
let cajasLogo = [
    Caja2D(nombre: "hola", x: 276.67662401146924, y: 329.0400961898879, w: 2053, h: 776), Caja2D(nombre: "¡", x: 65, y: 591, w: 122, h: 624),
    Caja2D(nombre: "{", x: 177, y: 1429, w: 214, h: 531), Caja2D(nombre: "Swift", x: 382, y: 1137, w: 2337, h: 1143),
    Caja2D(nombre: "!", x: 2796, y: 1322, w: 144, h: 604), Caja2D(nombre: "mano", x: 2236, y: 120, w: 459.90234375, h: 470),
]
let anchoLienzo = 3005.0

// MARK: - Arranque del hero

func prepararHeroe() {
    let hero = porId("hero"), stage = porId("stage")
    guard hero.object != nil, stage.object != nil else { return }
    let video = global.Boolean(global.VIDEO).boolean ?? false   // versión para grabar: el tiempo lo marca la captura, no el reloj
    let reducir = !video && quieto
    let piezas = fases.compactMap(Pieza.init)
    let guia = document.querySelector(".lead path"), mano = document.querySelector(".mano"), texto = document.querySelector(".copy")
    if guia.object != nil { guia.style.strokeDasharray = "1 1"; _ = guia.setAttribute("pathLength", "1") }
    let guiaDesplazamiento = Valor<Double> { d in guia.style.strokeDashoffset = .number(d) }
    let manoForma = Valor<String> { t in mano.style.transform = .string(t) }
    let reticula = Valor<Double> { g in _ = hero.style.setProperty("--grid", numeroJS(g)) }
    var preparado = false

    func fotograma(_ t: Double) {
        guiaDesplazamiento.poner(redondo(t < guiaVuelta.a ? 1 - frenada(progreso(t, guiaTrazo)) : -suave(progreso(t, guiaVuelta))))
        for pieza in piezas { pieza.fotograma(t) }
        let k = t - manoSaluda, ciclo = k < 0 ? -1 : k.truncatingRemainder(dividingBy: 5.5)
        let envolvente = ciclo >= 0 && ciclo < 1.5 ? sin(Double.pi * ciclo / 1.5) : 0
        manoForma.poner("scale(" + numeroJS(redondo(muelleEntrada(t - manoSalta))) + ") rotate(" + decimal2(-4 + 20 * envolvente * sin(ciclo * 13)) + "deg)")
        reticula.poner(redondo(1 - entre((t - 3.8) / 1.4, 0, 1) * 0.85))
        if t > listo && !preparado { preparado = true; _ = hero.classList.add("ready") }
        if video {
            let c = frenada(entre((t - listo) / 0.7, 0, 1))
            texto.style.opacity = .number(c); texto.style.transform = .string("translateY(" + numeroJS((1 - c) * 24) + "px)")
            texto.style.filter = .string("blur(" + numeroJS((1 - c) * 6) + "px)")
        }
    }

    let lupa = porId("lupa-c"), seleccion = porId("sel")
    let marco = buscar(".box", en: seleccion), asas = lista(seleccion.querySelectorAll(".h"))
    let etiquetaFondo = buscar(".tag rect", en: seleccion), etiquetaTexto = buscar(".tag text", en: seleccion)
    var lx = -9999.0, ly = -9999.0, lr = 0.0, gx = -9999.0, gy = -9999.0, gr = 0.0, elegida: Int? = nil
    let lupaX = Valor<String> { v in _ = lupa.setAttribute("cx", v) }, lupaY = Valor<String> { v in _ = lupa.setAttribute("cy", v) }
    let lupaR = Valor<String> { v in _ = lupa.setAttribute("r", v) }

    func elegir(_ x: Double, _ y: Double) -> Int? {
        var mejor: Int? = nil
        for (i, b) in cajasLogo.enumerated() where x > b.x - 40 && x < b.x + b.w + 40 && y > b.y - 40 && y < b.y + b.h + 40 {
            if mejor == nil || b.w * b.h < cajasLogo[mejor!].w * cajasLogo[mejor!].h { mejor = i }
        }
        return mejor
    }
    func dibujarSeleccion(_ b: Caja2D, _ k: Double) {
        let p = 10 * k, x = b.x - p, y = b.y - p, w = b.w + 2 * p, h = b.h + 2 * p, lado = 8 * k
        _ = marco.setAttribute("x", x); _ = marco.setAttribute("y", y); _ = marco.setAttribute("width", w); _ = marco.setAttribute("height", h)
        let esquinas = [(x, y), (x + w / 2, y), (x + w, y), (x + w, y + h / 2), (x + w, y + h), (x + w / 2, y + h), (x, y + h), (x, y + h / 2)]
        for (i, (cx, cy)) in esquinas.enumerated() where i < asas.count {
            _ = asas[i].setAttribute("x", cx - lado / 2); _ = asas[i].setAttribute("y", cy - lado / 2)
            _ = asas[i].setAttribute("width", lado); _ = asas[i].setAttribute("height", lado)
        }
        etiquetaTexto.textContent = .string(b.nombre); _ = etiquetaTexto.setAttribute("font-size", 12 * k)
        let tw = (Double(b.nombre.utf16.count) * 7.6 + 16) * k, th = 20 * k
        _ = etiquetaFondo.setAttribute("x", x); _ = etiquetaFondo.setAttribute("y", y - th - 6 * k)
        _ = etiquetaFondo.setAttribute("width", tw); _ = etiquetaFondo.setAttribute("height", th)
        _ = etiquetaTexto.setAttribute("x", x + 8 * k); _ = etiquetaTexto.setAttribute("y", y - th / 2 - 6 * k)
    }
    escuchar(stage, "pointermove") { e in
        guard mismoTexto(e.pointerType.string ?? "", "mouse"), hero.classList.contains("ready").boolean == true else { return }
        let r = Caja(stage), k = anchoLienzo / r.width
        gx = (decimal(e.clientX) - r.left) * k; gy = (decimal(e.clientY) - r.top) * k; gr = min(150, r.width * 0.17) * k
        if lx < -9000 { lx = gx; ly = gy }
        let b = elegir(gx, gy)
        if b != elegida { elegida = b; if let b { dibujarSeleccion(cajasLogo[b], k) }; _ = seleccion.classList.toggle("on", b != nil) }
    }
    escuchar(stage, "pointerleave") { _ in gr = 0; elegida = nil; _ = seleccion.classList.remove("on") }

    // leve giro con el puntero: solo mientras se mueve; quieto, vuelve a plano y se quita la transformación para que se pinte nítido
    var px = 0.0, py = 0.0, rx = 0.0, ry = 0.0, ultimoMovimiento = -1e9
    let giro = Valor<String> { t in stage.style.transform = .string(t) }
    escuchar(global, "pointermove") { e in
        px = decimal(e.clientX) / decimal(global.innerWidth) - 0.5; py = decimal(e.clientY) / altoVentana() - 0.5
        ultimoMovimiento = decimal(global.performance.now())
    }

    var tiempo = 0.0, velocidad = 1.0, anterior = decimal(global.performance.now())
    func bucle(_ ahora: Double) {
        // el reloj real manda aunque el navegador pinte lento (Safari con el hero puede ir a ~115 ms por fotograma):
        // con un tope de 0,05 s la animación iba a menos de la mitad de velocidad. El tope solo evita el salto al volver de otra pestaña
        let dt = min(0.25, (ahora - anterior) / 1000); anterior = ahora
        lx += (gx - lx) * 0.22; ly += (gy - ly) * 0.22; lr += (gr - lr) * 0.14
        if lupa.object != nil { lupaX.poner(decimal1(lx)); lupaY.poner(decimal1(ly)); lupaR.poner(decimal1(max(0, lr))) }
        guard !reducir else { return }
        tiempo += dt * velocidad; fotograma(tiempoDelPlan(tiempo))
        let quieto = ahora - ultimoMovimiento > 1200, tx = quieto ? 0 : -py * 5, ty = quieto ? 0 : px * 7
        rx += (tx - rx) * 0.06; ry += (ty - ry) * 0.06
        giro.poner(abs(rx) < 0.02 && abs(ry) < 0.02 ? "none" : "rotateX(" + decimal2(rx) + "deg) rotateY(" + decimal2(ry) + "deg)")
    }
    if reducir { fotograma(9); mano.style.transform = "none" }
    if !video {
        var siguiente: JSValue = .undefined
        siguiente = closure { marca in bucle(decimal(marca)); _ = global.requestAnimationFrame(siguiente) }
        _ = global.requestAnimationFrame(siguiente)
    }
    global.__hero = objetoJS([
        ("seek", closure { t in tiempo = decimal(t); fotograma(tiempo) }),
        ("pause", closure { _ in velocidad = 0 }),
    ])
    if !reducir && !video { fotograma(0) }   // el primer fotograma ya puesto, para que no se vea ni uno sin él
    _ = hero.classList.add("animado")   // el CSS deja de esconder el logo: a partir de aquí lo lleva Swift
    prepararLupaDelHero(hero: hero, stage: stage)
}

// MARK: - Lupa en todo el hero

/// Con ratón, el esqueleto de los glifos del fondo asoma bajo el cursor y cualquier pieza del hero se puede «seleccionar»,
/// como en un editor. Easter egg: solo el corazón lleva el cursor multijugador con la firma de quien lo diseñó.
func prepararLupaDelHero(hero: JSValue, stage: JSValue) {
    let seleccion = porId("seleccion"), colab = porId("colab")
    guard seleccion.object != nil else { return }
    let nombres: [(String, String)] = [("pregunta", "?"), ("llaves", "{ }"), ("abre", "¿"), ("corazon", "♥"), ("arroba", "@"), ("enye", "ñ")]
    func glifo(_ k: String) -> String {
        for (clave, nombre) in nombres where mismoTexto(clave, k) { return nombre }
        return "undefined"
    }
    let flotas = lista(document.querySelectorAll(".flota")).map { f -> (cuerpo: JSValue, esqueleto: JSValue, nombre: String) in
        let cuerpo = buscar(".cuerpo", en: f)
        return (cuerpo, buscar(".esq", en: f), "Glifo " + glifo(cuerpo.dataset.k.string ?? ""))
    }
    let titular = document.querySelector(".copy h1"), email = porId("email"), boton = document.querySelector("#signup .btn")
    func fuente(_ el: JSValue) -> String {
        let estilo = global.getComputedStyle(el)
        var familia = ""
        for c in (estilo.fontFamily.string ?? "").unicodeScalars {
            if c == "," { break }
            if c != "\"" { familia.unicodeScalars.append(c) }
        }
        return familia + " " + "\(Int(decimal(global.parseFloat(estilo.fontSize)).rounded()))"
    }
    func objetivos() -> [(el: JSValue, nombre: String)] {
        flotas.map { ($0.cuerpo, $0.nombre) } + [(titular, "Titular · " + fuente(titular)), (email, "Campo de email"), (boton, "Botón · Avísame")]
    }
    let etiqueta = buscar("b", en: seleccion), nombreColab = buscar("span", en: colab)
    var mx = -9999.0, my = -9999.0, sx = -9999.0, sy = -9999.0, lr = 0.0, lrMeta = 0.0
    var elegido: JSValue? = nil
    escuchar(hero, "pointermove") { e in
        guard mismoTexto(e.pointerType.string ?? "", "mouse"), hero.classList.contains("ready").boolean == true else { return }
        mx = decimal(e.clientX); my = decimal(e.clientY)
        if sx < -9000 { sx = mx; sy = my }
        lrMeta = min(150, Caja(stage).width * 0.17)
        var mejor: (el: JSValue, nombre: String, area: Double)? = nil
        if porId("sel").classList.contains("on").boolean != true {
            for o in objetivos() where o.el.object != nil {
                let r = Caja(o.el)
                if mx > r.left - 8 && mx < r.right + 8 && my > r.top - 8 && my < r.bottom + 8 && (mejor == nil || r.width * r.height < mejor!.area) {
                    mejor = (o.el, o.nombre, r.width * r.height)
                }
            }
        }
        elegido = mejor?.el
        _ = seleccion.classList.toggle("on", mejor != nil)
        if let mejor { etiqueta.textContent = .string(mejor.nombre) }
        let encima = mejoresCorazon(mejor?.el)
        colab.style.transform = .string("translate(" + numeroJS(mx - 2) + "px," + numeroJS(my - 1.5) + "px)")
        _ = colab.classList.toggle("izq", mx + decimal(nombreColab.offsetWidth) + 40 > decimal(global.innerWidth))
        _ = colab.classList.toggle("on", encima); _ = hero.classList.toggle("colab-on", encima)
    }
    escuchar(hero, "pointerleave") { _ in
        lrMeta = 0; elegido = nil
        _ = seleccion.classList.remove("on"); _ = colab.classList.remove("on"); _ = hero.classList.remove("colab-on")
    }
    let puestos = flotas.map { f in (Valor<String> { v in _ = f.esqueleto.style.setProperty("--lx", v) },
                                     Valor<String> { v in _ = f.esqueleto.style.setProperty("--ly", v) },
                                     Valor<String> { v in _ = f.esqueleto.style.setProperty("--lr", v) }) }
    let caja = (Valor<String> { v in seleccion.style.left = .string(v) }, Valor<String> { v in seleccion.style.top = .string(v) },
                Valor<String> { v in seleccion.style.width = .string(v) }, Valor<String> { v in seleccion.style.height = .string(v) })
    cadaFotograma {
        sx += (mx - sx) * 0.22; sy += (my - sy) * 0.22; lr += (lrMeta - lr) * 0.14
        let radio = decimal1(max(0, lr)) + "px"
        if lr > 0.04 || lrMeta > 0 {
            for (i, f) in flotas.enumerated() where f.esqueleto.object != nil {
                let r = Caja(f.esqueleto)
                puestos[i].0.poner(decimal1(sx - r.left) + "px"); puestos[i].1.poner(decimal1(sy - r.top) + "px"); puestos[i].2.poner(radio)
            }
        } else {
            for p in puestos { p.2.poner(radio) }
        }
        if let elegido {
            let r = Caja(elegido), h = Caja(hero), p = 6.0
            caja.0.poner(numeroJS(r.left - h.left - p) + "px"); caja.1.poner(numeroJS(r.top - h.top - p) + "px")
            caja.2.poner(numeroJS(r.width + 2 * p) + "px"); caja.3.poner(numeroJS(r.height + 2 * p) + "px")
        }
    }
}

func mejoresCorazon(_ el: JSValue?) -> Bool {
    guard let el else { return false }
    return mismoTexto(el.dataset.k.string ?? "", "corazon")
}
