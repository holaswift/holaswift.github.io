// Las animaciones son CSS; aquí se deciden los momentos (clases) y las posiciones (transform, variables CSS).
// Los bucles por fotograma solo tocan la página cuando algo cambia, para cruzar lo menos posible a JavaScript.

import HolaSwift
import JavaScriptKit

func numeroJS(_ x: Double) -> String { global.String(x).string ?? "0" }

func decimal1(_ x: Double) -> String {
    guard x.isFinite else { return "0.0" }
    let n = Int((x * 10).rounded()), a = n < 0 ? -n : n
    return (n < 0 ? "-" : "") + "\(a / 10).\(a % 10)"
}

func decimal(_ v: JSValue) -> Double {
    guard let n = global.Number(v).number, n.isFinite else { return 0 }
    return n
}

func entre0y1(_ x: Double) -> Double { x.isFinite ? min(1, max(0, x)) : 0 }

struct Caja {
    let left, top, width, height: Double
    var right: Double { left + width }
    var bottom: Double { top + height }
    init(_ el: JSValue) {
        let r = el.object != nil ? el.getBoundingClientRect() : .undefined
        left = decimal(r.left); top = decimal(r.top); width = decimal(r.width); height = decimal(r.height)
    }
}

func altoVentana() -> Double { decimal(global.innerHeight) }

func cadaFotograma(_ cuerpo: @escaping () -> Void) {
    var siguiente: JSValue = .undefined
    siguiente = closure { _ in
        cuerpo()
        _ = global.requestAnimationFrame(siguiente)
    }
    _ = global.requestAnimationFrame(siguiente)
}

/// Solo con http(s): abierta como archivo, cambiar la dirección da error.
let conServidor: Bool = {
    let protocolo = global.location.`protocol`.string ?? ""
    return mismoTexto(protocolo, "http:") || mismoTexto(protocolo, "https:")
}()

func cambiarDireccion(_ direccion: String) {
    if conServidor { _ = global.history.replaceState(JSValue.null, "", direccion) }
}

// MARK: - Apariciones

var observadorApariciones: JSValue = .undefined
let retrasos = ["0s", "0.08s", "0.16s"]

func aparece(_ raiz: JSValue) {
    for (i, el) in lista(raiz.querySelectorAll(".reveal:not(.in)")).enumerated() {
        el.style.transitionDelay = .string(masCercano(el, ".agenda,.personas,.eventos").object != nil ? retrasos[i % 3] : "0s")
        _ = observadorApariciones.observe(el)
    }
}

func prepararApariciones() {
    observadorApariciones = .object(global.IntersectionObserver.object!.new(closure { entradas in
        for e in lista(entradas) where e.isIntersecting.boolean == true {
            _ = e.target.classList.add("in")
            _ = observadorApariciones.unobserve(e.target)
        }
    }, objetoJS([("threshold", .number(0.2))])))
    aparece(document)
}

// MARK: - Barra de arriba

func prepararBarra() {
    let barra = porId("top"), titular = document.querySelector(".copy h1"), manifiesto = porId("manifiesto"), tema = porId("tema")
    let observador = global.IntersectionObserver.object!.new(closure { entradas in
        _ = barra.classList.toggle("solid", !(entradas[0].isIntersecting.boolean ?? false))
    }, objetoJS([("rootMargin", .string("-80px 0px 0px 0px"))]))
    if titular.object != nil { _ = JSValue.object(observador).observe(titular) }
    guard manifiesto.object != nil else { return }
    var oscura: Bool? = nil
    func mirar() {
        let r = Caja(manifiesto), mitad = decimal(barra.offsetHeight) * 0.5
        let ahora = r.top < mitad && r.bottom > mitad
        guard ahora != oscura else { return }
        oscura = ahora
        _ = barra.classList.toggle("oscura", ahora)
        if tema.object != nil { tema.content = .string(ahora ? "#0C0B0B" : "#F7F7F7") }
        document.documentElement.style.backgroundColor = .string(ahora ? "#0C0B0B" : "")
    }
    escuchar(global, "scroll", pasivo: true) { _ in mirar() }
    escuchar(global, "resize") { _ in mirar() }
    mirar()
}

// MARK: - Manifiesto y fondo

/// Pantallas que no se mueven: con «Reducir movimiento», o bajas y en horizontal (el manifiesto no queda fijo).
let quietas = global.matchMedia("(prefers-reduced-motion: reduce), (max-height:520px) and (orientation:landscape)").matches.boolean ?? false

func prepararManifiesto() {
    let seccion = porId("manifiesto"), texto = porId("manifiesto-txt"), grupo = porId("grupo"), entradilla = porId("manifiesto-lede")
    guard seccion.object != nil, texto.object != nil else { return }
    for nodo in lista(texto.querySelectorAll(".txt,.ya")) {
        let palabras = partir(nodo.textContent.string ?? "", por: " ")
        nodo.innerHTML = .string(palabras.map { #"<span class="w">"# + esc($0) + "</span>" }.joined(separator: " "))
    }
    let palabras = lista(texto.querySelectorAll(".w")), enFrase = Int(decimal(texto.querySelectorAll(".txt .w").length))
    if quietas {
        _ = seccion.classList.add("quieto")
        for w in palabras { _ = w.classList.add("on") }
        _ = grupo.classList.add("junto"); _ = entradilla.classList.add("in")
        return
    }
    var encendidas = Array(repeating: false, count: palabras.count), junto = false, entra = false
    cadaFotograma {
        let r = Caja(seccion), recorrido = r.height - altoVentana()
        let p = recorrido > 0 ? entre0y1(-r.top / recorrido) : 0
        let luz = Int((entre0y1((p - 0.04) / 0.5) * Double(enFrase)).rounded())
        for i in palabras.indices {
            let on = i < enFrase ? i < luz : p > 0.62
            if on != encendidas[i] { encendidas[i] = on; _ = palabras[i].classList.toggle("on", on) }
        }
        if (p > 0.66) != junto { junto = p > 0.66; _ = grupo.classList.toggle("junto", junto) }
        if (p > 0.74) != entra { entra = p > 0.74; _ = entradilla.classList.toggle("in", entra) }
    }
}

/// Como split() de JavaScript: también deja los trozos vacíos entre dos separadores seguidos.
func partir(_ t: String, por separador: Unicode.Scalar) -> [String] {
    var trozos: [String] = [], actual = ""
    for c in t.unicodeScalars {
        if c == separador { trozos.append(actual); actual = "" } else { actual.unicodeScalars.append(c) }
    }
    trozos.append(actual)
    return trozos
}

func prepararParalaje() {
    let flotas = lista(document.querySelectorAll(".flota"))
    guard !flotas.isEmpty else { return }
    let profundidad = flotas.map { decimal($0.dataset.d) }
    var fx = 0.0, fy = 0.0, cx = 0.0, cy = 0.0
    var puestos = Array(repeating: ("", ""), count: flotas.count)
    escuchar(global, "pointermove") { e in
        guard mismoTexto(e.pointerType.string ?? "", "mouse") else { return }
        fx = decimal(e.clientX) / decimal(global.innerWidth) - 0.5
        fy = decimal(e.clientY) / altoVentana() - 0.5
    }
    cadaFotograma {
        cx += (fx - cx) * 0.06; cy += (fy - cy) * 0.06
        guard !quietas else { return }
        for i in flotas.indices {
            let px = decimal1(-cx * profundidad[i]) + "px", py = decimal1(-cy * profundidad[i]) + "px"
            if !mismoTexto(px, puestos[i].0) { _ = flotas[i].style.setProperty("--px", px) }
            if !mismoTexto(py, puestos[i].1) { _ = flotas[i].style.setProperty("--py", py) }
            puestos[i] = (px, py)
        }
    }
}

// MARK: - La carta

/// El sobre de la sección despega, vuela al centro, salta el sello, se abre la solapa y la carta crece hasta poder leerse.
/// Al cerrar, se pliega y vuelve a su sobre. Esc o ✕ la cierran; #carta en la dirección la abre directamente.
func prepararCarta() {
    let capa = porId("carta")
    guard capa.object != nil else { return }
    let lectura = buscar(".lectura", en: capa), cerrarBoton = buscar(".cerrar-carta", en: capa), firmas = porId("firmas")
    let vuelo = buscar(".vuelo", en: capa), carta = buscar(".carta", en: capa), papel = buscar(".sobre-papel", en: vuelo)
    let sobre = document.querySelector(".grupo .sobre")
    var pendientes: [JSValue] = [], volver: JSValue = .undefined

    func resto() -> [JSValue] {
        lista(document.body.children).filter { !mismo($0, capa) && !mismoTexto($0.tagName.string ?? "", "SCRIPT") }
    }
    func trasladar(_ dx: Double, _ dy: Double, escala: Double) -> String {
        "translate(" + numeroJS(dx) + "px," + numeroJS(dy) + "px) scale(" + numeroJS(escala) + ")"
    }
    func paso(_ ms: Int, _ cuerpo: @escaping () -> Void) -> () -> Void {
        let c = closure { _ in cuerpo() }
        return { pendientes.append(global.setTimeout(c, ms)) }
    }

    let abrirse = closure { _ in _ = capa.classList.add("abierta") }
    let pasos = [
        paso(700) { _ = capa.classList.add("sello") },
        paso(900) { _ = capa.classList.add("solapa") },
        paso(1350) { _ = capa.classList.add("sale") },
        paso(2000) {
            let p = Caja(papel)
            _ = capa.classList.add("lee")
            let c = Caja(carta), k = p.width / c.width
            _ = carta.classList.add("desde")
            carta.style.transform = .string(trasladar(p.left - c.left - (c.width * (1 - k)) / 2, p.top - c.top, escala: k))
            _ = carta.offsetWidth   // que el navegador vea el punto de partida antes de animar
            _ = carta.classList.add("crece"); _ = carta.classList.remove("desde"); carta.style.transform = ""
        },
        paso(2800) { _ = carta.classList.remove("crece"); enfocar(cerrarBoton) },
    ]

    func abrir(directo: Bool) {
        guard capa.hidden.boolean == true else { return }
        volver = document.activeElement
        capa.hidden = .boolean(false); document.documentElement.style.overflow = "hidden"
        for el in resto() { el.inert = .boolean(true) }
        cambiarDireccion("#carta")
        if directo || quieto {
            _ = capa.classList.add("abierta", "sello", "solapa", "sale", "lee"); enfocar(cerrarBoton); return
        }
        let r = Caja(sobre)
        if r.width > 0 {
            let v = Caja(vuelo)
            vuelo.style.transition = "none"; vuelo.style.opacity = "1"
            vuelo.style.transform = .string(trasladar(r.left + r.width / 2 - (v.left + v.width / 2), r.top + r.height / 2 - (v.top + v.height / 2), escala: r.width / v.width))
            sobre.style.visibility = "hidden"
            _ = vuelo.offsetWidth
            vuelo.style.transition = ""; vuelo.style.transform = ""; vuelo.style.opacity = ""
        }
        _ = global.requestAnimationFrame(abrirse)
        for p in pasos { p() }
    }

    func terminar() {
        capa.hidden = .boolean(true)
        _ = capa.classList.remove("lee", "sale", "solapa", "sello", "abierta", "cierra")
        lectura.scrollTop = .number(0); _ = firmas.classList.remove("in")
        _ = carta.classList.remove("crece", "desde", "vuelve"); carta.style.transform = ""
        if sobre.object != nil { sobre.style.visibility = "" }
    }
    let terminarLuego = closure { _ in terminar() }
    let devolverFoco = closure { _ in enfocar(volver) }

    func cerrar() {
        guard capa.hidden.boolean == false, capa.classList.contains("cierra").boolean != true else { return }
        for t in pendientes { _ = global.clearTimeout(t) }
        pendientes = []
        for el in resto() { el.inert = .boolean(false) }
        document.documentElement.style.overflow = ""
        cambiarDireccion((global.location.pathname.string ?? "") + (global.location.search.string ?? ""))
        _ = global.setTimeout(devolverFoco, 0)
        if quieto { terminar(); return }
        let c = Caja(carta), r = Caja(sobre)
        _ = capa.classList.add("cierra")
        if r.width > 0 && r.bottom > 0 && r.top < altoVentana() {
            _ = carta.classList.add("vuelve")
            carta.style.transform = .string(trasladar(r.left + r.width / 2 - (c.left + c.width / 2), r.top + r.height * 0.2 - c.top, escala: r.width / c.width))
        }
        _ = global.setTimeout(terminarLuego, 520)
    }

    for boton in lista(document.querySelectorAll("[data-abre-carta]")) { escuchar(boton, "click") { _ in abrir(directo: false) } }
    escuchar(cerrarBoton, "click") { _ in cerrar() }
    escuchar(lectura, "click") { e in if mismo(e.target, lectura) { cerrar() } }
    escuchar(global, "keydown") { e in if mismoTexto(e.key.string ?? "", "Escape") { cerrar() } }
    let observador = global.IntersectionObserver.object!.new(closure { entradas in
        for e in lista(entradas) where e.isIntersecting.boolean == true { _ = firmas.classList.add("in") }
    }, objetoJS([("root", lectura), ("threshold", .number(0.6))]))
    _ = JSValue.object(observador).observe(firmas)
    if mismoTexto(global.location.hash.string ?? "", "#carta") { abrir(directo: true) }
}

func prepararPagina() {
    prepararApariciones()
    prepararBarra()
    prepararManifiesto()
    prepararParalaje()
    prepararCarta()
}
