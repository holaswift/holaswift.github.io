// Las hojas de la página (ficha de embajador, quedada, «Avísame», patrocinio) y sus formularios.
//
// Lo común va en Hoja: aparecer con su animación, cerrarse con Esc o pulsando fuera, dejar el resto de la página
// inerte mientras está abierta (el foco no se escapa con Tab) y devolver el foco al botón que la abrió.
// La animación en sí es CSS: aquí solo se ponen y quitan `hidden` y la clase `abierta`.

import HolaSwift
import JavaScriptKit

// MARK: - Ayudas para hablar con la página

/// Los JSClosure tienen que seguir vivos mientras la página los pueda llamar.
var vivos: [JSClosure] = []

func closure(_ cuerpo: @escaping (JSValue) -> Void) -> JSValue {
    let c = JSClosure { argumentos in
        cuerpo(argumentos.first ?? .undefined)
        return .undefined
    }
    vivos.append(c)
    return .object(c)
}

func escuchar(_ v: JSValue, _ evento: String, pasivo: Bool = false, _ cuerpo: @escaping (JSValue) -> Void) {
    guard v.object != nil else { return }
    _ = v.addEventListener(evento, closure(cuerpo), pasivo ? objetoJS([("passive", .boolean(true))]) : .undefined)
}

func objetoJS(_ pares: [(String, JSValue)]) -> JSValue {
    let o = global.Object.object!.new()
    for (clave, valor) in pares { o[clave] = valor }
    return .object(o)
}

func porId(_ id: String) -> JSValue { document.getElementById(id) }

func mismo(_ a: JSValue, _ b: JSValue) -> Bool { global.Object.is(a, b).boolean ?? false }

/// closest() solo existe en elementos: un clic puede llegar desde otra cosa, y llamar a un método que no está detiene Swift.
func masCercano(_ v: JSValue, _ selector: String) -> JSValue {
    guard v.object?["closest"].function != nil else { return .null }
    return v.closest(selector)
}

let sinDesplazar = objetoJS([("preventScroll", .boolean(true))])

func enfocar(_ v: JSValue, desplazar: Bool = false) {
    guard v.object?["focus"].function != nil else { return }
    _ = desplazar ? v.focus() : v.focus(sinDesplazar)
}

func valor(_ campo: JSValue) -> String { recortar(campo.value.string ?? "") }

let quieto = global.matchMedia("(prefers-reduced-motion: reduce)").matches.boolean ?? false

// MARK: - Hoja

final class Hoja {
    let capa: JSValue
    let msCerrar: Int
    var volver: JSValue = .undefined
    var foco: JSValue = .undefined
    var abierta: Bool { capa.hidden.boolean == false }
    var entrar: JSValue = .undefined, animar: JSValue = .undefined, ocultar: JSValue = .undefined
    var devolverFoco: JSValue = .undefined, enfocarFoco: JSValue = .undefined

    /// `msCerrar`: lo que dura la animación de salida en CSS; después se oculta del todo.
    init?(_ id: String, msCerrar: Int) {
        capa = porId(id)
        guard capa.object != nil else { return nil }
        self.msCerrar = msCerrar
        entrar = closure { _ in _ = self.capa.classList.add("abierta") }
        animar = closure { _ in _ = global.requestAnimationFrame(self.entrar) }   // dos fotogramas: que el CSS vea el cambio
        ocultar = closure { _ in self.capa.hidden = .boolean(true) }
        devolverFoco = closure { _ in enfocar(self.volver) }
        enfocarFoco = closure { _ in enfocar(self.foco) }
        _ = document.body.appendChild(capa)
        let observador = global.MutationObserver.object!.new(closure { _ in self.inerte() })
        let filtro = global.Array.object!.new()
        _ = JSValue.object(filtro).push("hidden", "class")
        _ = JSValue.object(observador).observe(capa, objetoJS([("attributes", .boolean(true)), ("attributeFilter", .object(filtro))]))
    }

    func inerte() {
        let abierta = self.abierta && (capa.classList.contains("abierta").boolean ?? false)
        for el in lista(document.body.children) {
            if mismo(el, capa) || mismoTexto(el.tagName.string ?? "", "SCRIPT") || mismoTexto(el.id.string ?? "", "carta") { continue }
            el.inert = .boolean(abierta)
        }
    }

    func mostrar(foco: JSValue, esperar: Bool = false) {
        volver = document.activeElement
        self.foco = foco
        capa.hidden = .boolean(false)
        document.documentElement.style.overflow = "hidden"
        _ = global.requestAnimationFrame(animar)
        if esperar { _ = global.setTimeout(enfocarFoco, quieto ? 0 : 350) } else { enfocar(foco) }
    }

    func cerrar() {
        guard abierta else { return }
        _ = capa.classList.remove("abierta")
        document.documentElement.style.overflow = ""
        _ = global.setTimeout(ocultar, quieto ? 0 : msCerrar)
        _ = global.setTimeout(devolverFoco, 0)
    }

    func cerrarAlPulsarFuera(fondo: String) {
        escuchar(capa, "click") { e in
            if mismo(e.target, self.capa) || (e.target.classList.contains(fondo).boolean ?? false) { self.cerrar() }
        }
    }
}

/// En móvil, una hoja se cierra arrastrándola hacia abajo desde arriba, o con un tirón rápido, como en iOS.
func arrastrarParaCerrar(_ hoja: Hoja, panel selector: String, cerrar boton: String) {
    let panel = buscar(selector, en: hoja.capa), fondo = buscar("[class$=\"fondo\"]", en: hoja.capa)
    var y0: Double? = nil, dy = 0.0, t0 = 0.0
    func movil() -> Bool { global.matchMedia("(max-width:639px)").matches.boolean ?? false }
    escuchar(panel, "touchstart", pasivo: true) { e in
        guard movil(), (panel.scrollTop.number ?? 0) <= 0 else { return }
        y0 = e.touches[0].clientY.number; dy = 0; t0 = global.performance.now().number ?? 0
    }
    escuchar(panel, "touchmove", pasivo: true) { e in
        guard let y0 else { return }
        dy = max(0, (e.touches[0].clientY.number ?? y0) - y0)
        if dy > 0 {
            _ = panel.classList.add("arrastra")
            panel.style.transform = .string("translateY(\(Int(dy))px)")
            fondo.style.opacity = .number(max(0, 1 - dy / 400))
        }
    }
    escuchar(panel, "touchend") { _ in
        guard y0 != nil else { return }
        let velocidad = dy / max(1, (global.performance.now().number ?? 0) - t0)
        y0 = nil
        _ = panel.classList.remove("arrastra"); panel.style.transform = ""; fondo.style.opacity = ""
        if dy > 110 || (velocidad > 0.6 && dy > 40) { _ = buscar(boton, en: hoja.capa).click() }
    }
}

// MARK: - Las hojas de la página

var hojas: [Hoja] = []

func prepararFicha() {
    guard let hoja = Hoja("ficha", msCerrar: 420) else { return }
    hojas.append(hoja)
    let panel = buscar(".ficha", en: hoja.capa)
    func abrir(_ p: JSValue) {
        let foto = buscar(".foto", en: p), cara = buscar(".cara", en: panel)
        cara.src = foto.object != nil ? foto.src : ""
        cara.hidden = .boolean(foto.object == nil)
        buscar("h3", en: panel).textContent = buscar("h3", en: p).textContent
        buscar(".rol", en: panel).textContent = buscar(".rol", en: p).textContent
        let bio = buscar(".bio", en: p)
        buscar(".bio-txt", en: panel).textContent = .string(bio.object != nil ? recortar(bio.textContent.string ?? "") : "")
        buscar(".acciones", en: panel).innerHTML = .string(lista(p.querySelectorAll(".redes a")).map { a in
            let red = trasUltimo(" en ", a.getAttribute("aria-label").string ?? "")
            return #"<a href=""# + esc(a.href.string ?? "") + #"" target="_blank" rel="noopener me">"# + (a.innerHTML.string ?? "")
                + "<span>" + esc(mismoTexto(red, "su web") ? "Web" : red) + "</span></a>"
        }.joined())
        hoja.mostrar(foco: buscar(".cerrar", en: panel))
    }
    for p in lista(document.querySelectorAll(".embajadores-lista .persona")) {
        let mas = buscar(".mas", en: p)
        guard mas.object != nil else { continue }
        _ = mas.setAttribute("aria-haspopup", "dialog"); _ = mas.removeAttribute("aria-expanded"); _ = mas.removeAttribute("aria-controls")
        escuchar(mas, "click") { _ in abrir(p) }
        escuchar(buscar(".retrato", en: p), "click") { e in if masCercano(e.target, ".mas").object == nil { abrir(p) } }
    }
    escuchar(buscar(".ficha-fondo", en: hoja.capa), "click") { _ in hoja.cerrar() }
    escuchar(buscar(".cerrar", en: panel), "click") { _ in hoja.cerrar() }
    arrastrarParaCerrar(hoja, panel: ".ficha", cerrar: ".cerrar")
}

func trasUltimo(_ separador: String, _ t: String) -> String {
    let letras = Array(t.unicodeScalars), sep = Array(separador.unicodeScalars)
    guard letras.count >= sep.count else { return t }
    var i = letras.count - sep.count
    while i >= 0 {
        if Array(letras[i..<(i + sep.count)]) == sep {
            var s = ""
            for c in letras[(i + sep.count)...] { s.unicodeScalars.append(c) }
            return s
        }
        i -= 1
    }
    return t
}

var hojaQuedada: Hoja? = nil

func prepararQuedada() {
    guard let hoja = Hoja("cal", msCerrar: 420) else { return }
    hojas.append(hoja); hojaQuedada = hoja
    let panel = buscar(".cal-hoja", en: hoja.capa)
    let accion = buscar(".cal-accion", en: panel), formulario = buscar(".cal-form", en: panel), nota = buscar(".cal-nota", en: panel)
    func tapa() {
        let queda = (panel.scrollHeight.number ?? 0) - (panel.scrollTop.number ?? 0) - (panel.clientHeight.number ?? 0)
        _ = accion.classList.toggle("tapa", queda > 1)
    }
    escuchar(panel, "scroll", pasivo: true) { _ in tapa() }
    let observador = JSValue.object(global.ResizeObserver.object!.new(closure { _ in tapa() }))
    for el in [panel, accion, buscar(".cal-charlas", en: panel)] { _ = observador.observe(el) }
    escuchar(buscar(".cal-cerrar", en: panel), "click") { _ in hoja.cerrar() }
    escuchar(buscar(".cal-fondo", en: hoja.capa), "click") { _ in hoja.cerrar() }
    escuchar(buscar(".cal-apuntar", en: panel), "click") { _ in
        buscar(".cal-apuntar", en: panel).hidden = .boolean(true); formulario.hidden = .boolean(false)
        enfocar(buscar("#cal-email", en: panel), desplazar: true)
    }
    escuchar(formulario, "submit") { e in
        _ = e.preventDefault()
        guard esEmail(valor(buscar("#cal-email", en: panel))) else {
            _ = nota.classList.add("err"); nota.textContent = "Revisa el email: parece que le falta algo."; return
        }
        formulario.hidden = .boolean(true); buscar(".cal-ok", en: panel).hidden = .boolean(false); _ = formulario.reset()
    }
    arrastrarParaCerrar(hoja, panel: ".cal-hoja", cerrar: ".cal-cerrar")
}

func mostrarQuedada() {
    guard let hoja = hojaQuedada else { return }
    let panel = buscar(".cal-hoja", en: hoja.capa), nota = buscar(".cal-nota", en: panel)
    buscar(".cal-apuntar", en: panel).hidden = .boolean(false)
    buscar(".cal-form", en: panel).hidden = .boolean(true)
    buscar(".cal-ok", en: panel).hidden = .boolean(true)
    _ = nota.classList.remove("err")
    nota.innerHTML = #"Al apuntarte aceptas la <a href="privacidad.html">política de privacidad</a>."#
    hoja.mostrar(foco: buscar(".cal-cerrar", en: panel))
    panel.scrollTop = .number(0)
    let queda = (panel.scrollHeight.number ?? 0) - (panel.clientHeight.number ?? 0)
    _ = buscar(".cal-accion", en: panel).classList.toggle("tapa", queda > 1)
}

func prepararFormulario(_ id: String, abre selector: String, delegado: Bool, primerCampo: String,
                        validar: @escaping () -> (mensaje: String, campo: String)?) {
    guard let hoja = Hoja(id, msCerrar: 400) else { return }
    hojas.append(hoja)
    let formulario = porId(id + "-form"), gracias = buscar(".patro-ok", en: hoja.capa), error = porId(id + "-error")
    func abrir() {
        formulario.hidden = .boolean(false); gracias.hidden = .boolean(true); error.textContent = ""
        hoja.mostrar(foco: porId(primerCampo), esperar: true)
    }
    if delegado {   // «Avísame» está en la barra, en el encuentro y en la tarjeta de «muy pronto», que pinta Swift
        escuchar(document, "click") { e in
            if masCercano(e.target, selector).object != nil { _ = e.preventDefault(); abrir() }
        }
    } else {
        for boton in lista(document.querySelectorAll(selector)) { escuchar(boton, "click") { _ in abrir() } }
    }
    for boton in lista(hoja.capa.querySelectorAll(".cerrar,[data-cierra-" + id + "]")) { escuchar(boton, "click") { _ in hoja.cerrar() } }
    hoja.cerrarAlPulsarFuera(fondo: "patro-fondo")
    escuchar(formulario, "submit") { e in
        _ = e.preventDefault()
        if let fallo = validar() {
            error.textContent = .string(fallo.mensaje)
            enfocar(porId(fallo.campo), desplazar: true)
            return
        }
        error.textContent = ""; formulario.hidden = .boolean(true); gracias.hidden = .boolean(false); _ = formulario.reset()
        enfocar(buscar("button", en: gracias))
    }
}

func prepararAvisame() {
    prepararFormulario("apunte", abre: "[data-abre-apunte]", delegado: true, primerCampo: "apunte-email") {
        let email = valor(porId("apunte-email"))
        if !esEmail(email) { return (email.isEmpty ? "Escribe tu email para avisarte." : "Revisa el email: parece que le falta algo.", "apunte-email") }
        if porId("apunte-acepto").checked.boolean != true { return ("Necesitamos que aceptes la política de privacidad.", "apunte-acepto") }
        return nil
    }
}

func prepararPatrocinio() {
    prepararFormulario("patro", abre: "[data-abre-patro]", delegado: false, primerCampo: "patro-nombre") {
        if valor(porId("patro-nombre")).isEmpty { return ("Dinos cómo te llamas.", "patro-nombre") }
        if !esEmail(valor(porId("patro-email"))) { return ("Revisa el email: parece que le falta algo.", "patro-email") }
        if valor(porId("patro-mensaje")).isEmpty { return ("Cuéntanos un poco en el mensaje.", "patro-mensaje") }
        if porId("patro-acepto").checked.boolean != true { return ("Necesitamos que aceptes la política de privacidad.", "patro-acepto") }
        return nil
    }
}

/// El formulario del principio de la página: valida y confirma (el envío real depende de la herramienta que elijan).
func prepararApuntarse() {
    let formulario = porId("signup"), nota = porId("signup-note"), email = porId("email")
    escuchar(formulario, "submit") { e in
        _ = e.preventDefault()
        let texto = valor(email)
        if texto.isEmpty {
            nota.className = "signup-note err"; nota.textContent = "Escribe tu email para que podamos avisarte."; enfocar(email, desplazar: true); return
        }
        if email.checkValidity().boolean != true || !esEmail(texto) {
            nota.className = "signup-note err"; nota.textContent = "Ese email no parece correcto. Revisa que lleve @ y dominio."; enfocar(email, desplazar: true); return
        }
        buscar("button", en: formulario).disabled = .boolean(true); email.disabled = .boolean(true)
        nota.className = "signup-note ok"; nota.textContent = "¡Hecho! Te avisamos cuando arranquemos."
    }
}

func prepararHojas() {
    prepararApuntarse()
    prepararAvisame()
    prepararFicha()
    prepararPatrocinio()
    prepararQuedada()
    escuchar(global, "keydown") { e in
        if mismoTexto(e.key.string ?? "", "Escape") { for hoja in hojas { hoja.cerrar() } }
    }
}
