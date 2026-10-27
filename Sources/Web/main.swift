// Lo que corre en el navegador, compilado a WebAssembly con Embedded Swift: ./scripts/compilar-web.sh lo deja en assets/swift/.
//
// Embedded Swift no tiene Codable: los datos se leen campo a campo del objeto de JavaScript. Los números y las fechas
// los resuelve JavaScript (Number, Intl, Date), que ya está en el navegador, para que el .wasm no tenga que llevarlos.

import HolaSwift
import JavaScriptKit

let global = JSValue.object(JSObject.global)
let document = global.document

func buscar(_ selector: String, en raiz: JSValue = document) -> JSValue {
    raiz.querySelector(selector)
}

/// El número que hay en un valor de JavaScript, o nil si no lo es. Pasar NaN a Int detiene Swift (trap), así que se mira antes.
func numero(_ v: JSValue) -> Int? {
    guard let n = global.Number(v).number, n.isFinite else { return nil }
    return Int(n)
}

func opciones(_ pares: [(String, String)]) -> JSValue {
    let o = global.Object.object!.new()
    for (clave, valor) in pares { o[clave] = .string(valor) }
    return .object(o)
}

// MARK: - Leer los datos de la página

func texto(_ o: JSValue, _ clave: String) -> String? { o.object?[clave].string }

func lista(_ o: JSValue) -> [JSValue] {
    guard let n = o.length.number else { return [] }
    return (0..<Int(n)).map { o[$0] }
}

func quedada(_ o: JSValue) -> Quedada? {
    guard let fecha = texto(o, "fecha"), let titulo = texto(o, "titulo") else { return nil }
    let charlas = lista(o.charlas).compactMap { c -> Charla? in
        guard let titulo = texto(c, "titulo") else { return nil }
        let ponentes = c.ponentes.object == nil ? nil : lista(c.ponentes).compactMap { p -> Ponente? in
            texto(p, "nombre").map { Ponente(nombre: $0, foto: texto(p, "foto")) }
        }
        return Charla(titulo: titulo, ponentes: ponentes, tipo: texto(c, "tipo"), descripcion: texto(c, "descripcion"))
    }
    return Quedada(fecha: fecha, titulo: titulo, notas: texto(o, "notas"), enlace: texto(o, "enlace"), demo: o.demo.boolean, charlas: charlas)
}

// MARK: - Fechas, con el Intl del navegador

let madrid = "Europe/Madrid"
let partes = global.Intl.DateTimeFormat.object!.new("en-US", opciones([
    ("timeZone", madrid), ("year", "numeric"), ("month", "numeric"), ("day", "numeric"),
    ("hour", "numeric"), ("minute", "numeric"), ("hourCycle", "h23"),
]))
let fechaLarga = global.Intl.DateTimeFormat.object!.new("es-ES", opciones([
    ("timeZone", madrid), ("weekday", "long"), ("day", "numeric"), ("month", "long"), ("year", "numeric"),
]))

func momento(_ ms: Double) -> Momento {
    var anio = 0, mes = 1, dia = 1, hora = 0, minuto = 0
    for parte in lista(JSValue.object(partes).formatToParts(ms)) {
        guard let valor = numero(parte.value) else { continue }
        let tipo = parte.type.string ?? ""
        if mismoTexto(tipo, "year") { anio = valor }
        else if mismoTexto(tipo, "month") { mes = valor }
        else if mismoTexto(tipo, "day") { dia = valor }
        else if mismoTexto(tipo, "hour") { hora = valor }
        else if mismoTexto(tipo, "minute") { minuto = valor }
    }
    return Momento(ms: ms, anio: anio, mes: mes, dia: dia, hora: hora, minuto: minuto)
}

func ahora() -> Double { global.Date.now().number ?? 0 }
func instante(_ fecha: String) -> Double { global.Date.parse(fecha).number ?? 0 }

// MARK: - Quedadas

/// nil si no se pudieron leer: entonces se quedan las tarjetas que ya trae el HTML, sin tocarlas.
let leidas: [Quedada]? = {
    guard let json = buscar("#quedadas-datos").textContent.string else { return nil }
    let datos = global.JSON.parse(json)
    guard global.Array.isArray(datos).boolean == true else { return nil }
    let quedadas = lista(datos).compactMap(quedada)
    return quedadas.count == lista(datos).count ? quedadas : nil
}()
let quedadas = leidas ?? []
let momentos = quedadas.map { momento(instante($0.fecha)) }
let hoy = momento(ahora())

func pintarQuedadas() {
    let lista = buscar("#eventos-lista")
    guard lista.object != nil else { return }
    lista.innerHTML = .string(tarjetas(quedadas, momentos: momentos, hoy: hoy))
    aparece(lista)
}

/// (En Swift y no con replace() de JavaScript: el resultado de toISOString() es un texto, no un objeto, y JavaScriptKit
/// solo llama a métodos de objetos.)
func horaCalendario(_ ms: Double) -> String {
    let iso = JSValue.object(global.Date.object!.new(ms)).toISOString().string ?? ""
    var s = "", saltar = 0
    for c in iso.unicodeScalars {
        if saltar > 0 { saltar -= 1; continue }
        if c == "." { saltar = 3; continue }
        if c != "-" && c != ":" { s.unicodeScalars.append(c) }
    }
    return s
}

func calendario(_ q: Quedada, _ m: Momento) -> String {
    let lineas = [
        "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//hola Swift//ES", "BEGIN:VEVENT",
        "UID:" + horaCalendario(m.ms) + "-holaswift", "DTSTAMP:" + horaCalendario(ahora()),
        "DTSTART:" + horaCalendario(m.ms), "DTEND:" + horaCalendario(m.ms + Double(minutos(q)) * 60_000),
        "SUMMARY:" + textoCalendario("hola Swift: " + q.titulo), "DESCRIPTION:" + textoCalendario(descripcionCalendario(q)),
        "LOCATION:Discord", "END:VEVENT", "END:VCALENDAR",
    ]
    return "data:text/calendar;charset=utf-8," + (global.encodeURIComponent(lineas.joined(separator: "\r\n")).string ?? "")
}

func abrirHoja(_ i: Int) {
    let hoja = buscar("#cal .cal-hoja")
    guard quedadas.indices.contains(i), hoja.object != nil else { return }
    let q = quedadas[i], m = momentos[i], pasado = yaPaso(m, hoy: hoy)
    let fecha = JSValue.object(fechaLarga).format(m.ms).string ?? ""
    var en = buscar(".cal-tipo", en: hoja); en.textContent = .string(categoria(q) + (q.demo == true ? " · Ejemplo" : ""))
    en = buscar("h3", en: hoja); en.textContent = .string(q.titulo)
    en = buscar(".cal-cuando", en: hoja); en.innerHTML = .string(mayusculaInicial(fecha) + "<span>" + m.horaMinuto + " (hora de Madrid) · Discord</span>")
    en = buscar(".cal-charlas", en: hoja); en.innerHTML = .string(charlasHoja(q))
    en = buscar(".cal-notas .cal-desc", en: hoja); en.textContent = .string(q.notas ?? "")
    en = buscar(".cal-notas", en: hoja); en.hidden = .boolean(q.notas == nil)
    en = buscar(".cal-ics", en: hoja); en.href = .string(calendario(q, m))
    en = buscar(".cal-accion", en: hoja); en.hidden = .boolean(pasado)
    _ = hoja.classList.toggle("sin-accion", pasado)
    mostrarQuedada()
}

let alPulsarTarjeta = JSClosure { argumentos in
    let boton = masCercano(argumentos[0].target, "[data-evento]")
    if boton.object != nil, let i = numero(boton.dataset.evento) { abrirHoja(i) }
    return .undefined
}

// MARK: - Embajadores

/// Cada visita en un orden distinto, para que nadie salga siempre primero. El hueco de «Muy pronto» se queda al final.
func barajarEmbajadores() {
    let contenedor = buscar(".embajadores-lista")
    guard contenedor.object != nil else { return }
    var personas = lista(contenedor.querySelectorAll(":scope > article.persona"))
    if personas.count > 1 {
        for i in stride(from: personas.count - 1, to: 0, by: -1) {
            personas.swapAt(i, Int((global.Math.random().number ?? 0) * Double(i + 1)))
        }
    }
    for persona in personas.reversed() { _ = contenedor.prepend(persona) }
}

// MARK: - Arranque

prepararHeroe()

/// Lo demás, cuando el logo ya lleva dos fotogramas en marcha: así no le quita tiempo al principio de la animación.
func prepararElResto() {
    prepararPagina()
    barajarEmbajadores()
    if leidas != nil { pintarQuedadas() }
    prepararHojas()
    prepararDuo()
    _ = buscar("#eventos-lista").addEventListener("click", JSValue.object(alPulsarTarjeta))
    document.documentElement.dataset.swift = "listo"   // <html data-swift="listo">: Swift ya ha arrancado
    _ = global.console.log("hola 👋 Esta web corre en Swift compilado a WebAssembly.")
}
let despues = closure { _ in prepararElResto() }
_ = global.requestAnimationFrame(closure { _ in _ = global.requestAnimationFrame(closure { _ in _ = global.setTimeout(despues, 0) }) })
