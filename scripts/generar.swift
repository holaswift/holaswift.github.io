#!/usr/bin/env swift
// Comprueba datos/*.json y escribe con ellos el equipo, las quedadas y los patrocinadores en index.html.
//
// Solo toca lo que hay entre cada par de marcas:
//     <!-- generado:NOMBRE … -->
//     <!-- /generado:NOMBRE -->
// El resto de la página no se toca, y pasarlo dos veces da lo mismo.
//
// Uso, desde la raíz del repo:
//     swift scripts/generar.swift              comprueba los datos y escribe index.html
//     swift scripts/generar.swift --comprobar  solo comprueba: que los datos están bien y que index.html está al día

import Foundation

let raiz = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let pagina = raiz.appending(path: "index.html")
let madrid = TimeZone(identifier: "Europe/Madrid")!

// MARK: - Datos

struct Persona: Decodable {
    let nombre, rol, foto, bio: String
    let x, linkedin, web: String?
}

/// Una quedada online: un título propio y de 1 a 3 charlas.
struct Quedada: Decodable {
    let fecha, titulo: String
    let notas, enlace: String?
    let demo: Bool?
    let charlas: [Charla]
}

/// Cada charla dura 20 minutos como mucho. `tipo` solo se pone si es un taller.
struct Charla: Decodable {
    let titulo: String
    let ponentes: [Ponente]?
    let tipo, descripcion: String?
    var esTaller: Bool { tipo == "Taller" }
}

/// Sin foto, en su círculo salen sus iniciales.
struct Ponente: Decodable {
    let nombre: String
    let foto: String?
}

/// Una marca que patrocina: su logo en el muro de la sección de patrocinio, enlazado a su web.
struct Patrocinador: Decodable {
    let nombre, logo: String
    let web: String?
}

let camposPersona: Set = ["nombre", "rol", "foto", "bio", "x", "linkedin", "web"]
let camposQuedada: Set = ["fecha", "titulo", "notas", "enlace", "demo", "charlas"]
let camposCharla: Set = ["titulo", "ponentes", "tipo", "descripcion"]
let camposPonente: Set = ["nombre", "foto"]
let camposPatrocinador: Set = ["nombre", "logo", "web"]

/// Lee un JSON de datos/ y apunta en `errores` todo lo que no cuadre, con el número de entrada para encontrarlo rápido.
func leer<T: Decodable>(_ archivo: String, campos: Set<String>, charlas: Set<String> = [], errores: inout [String]) -> [T] {
    guard let datos = try? Data(contentsOf: raiz.appending(path: "datos/\(archivo)")) else {
        errores.append("\(archivo): no se encuentra"); return []
    }
    guard let lista = try? JSONSerialization.jsonObject(with: datos) as? [[String: Any]] else {
        errores.append("\(archivo): no es un JSON válido o no es una lista [ … ] (revisa comas y comillas)"); return []
    }
    // cada entrada por separado, para avisar de todos los fallos de una vez y no solo del primero
    return lista.enumerated().compactMap { i, item in
        let donde = "\(archivo) #\(i + 1)"
        let sobran = Set(item.keys).subtracting(campos)
        if !sobran.isEmpty { errores.append("\(donde): campos que la web no usa: \(sobran.sorted().joined(separator: ", "))") }
        for (j, charla) in ((item["charlas"] as? [[String: Any]]) ?? []).enumerated() {
            let sobran = Set(charla.keys).subtracting(charlas)
            if !sobran.isEmpty { errores.append("\(donde), charla \(j + 1): campos que la web no usa: \(sobran.sorted().joined(separator: ", "))") }
            for (k, ponente) in ((charla["ponentes"] as? [Any]) ?? []).enumerated() {
                guard let ponente = ponente as? [String: Any] else {
                    errores.append("\(donde), charla \(j + 1), ponente \(k + 1): tiene que ser { \"nombre\": …, \"foto\": … }"); continue
                }
                let sobran = Set(ponente.keys).subtracting(camposPonente)
                if !sobran.isEmpty { errores.append("\(donde), charla \(j + 1), ponente \(k + 1): campos que la web no usa: \(sobran.sorted().joined(separator: ", "))") }
            }
        }
        do {
            return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: item))
        } catch let DecodingError.keyNotFound(clave, _) {
            errores.append("\(donde): falta \"\(clave.stringValue)\"")
        } catch let DecodingError.typeMismatch(_, contexto), let DecodingError.valueNotFound(_, contexto) {
            errores.append("\(donde): \"\(contexto.codingPath.last?.stringValue ?? "?")\" no tiene el tipo que toca (texto, número o true/false)")
        } catch {
            errores.append("\(donde): \(error.localizedDescription)")
        }
        return nil
    }
}

func comprobar(_ marcas: [Patrocinador], errores: inout [String]) {
    for (i, m) in marcas.enumerated() {
        let donde = "patrocinadores.json #\(i + 1)"
        if m.nombre.trimmingCharacters(in: .whitespaces).isEmpty { errores.append("\(donde): \"nombre\" está vacío") }
        if !FileManager.default.fileExists(atPath: raiz.appending(path: m.logo).path) { errores.append("\(donde): no existe el logo \(m.logo)") }
        if let web = m.web, !web.hasPrefix("https://") { errores.append("\(donde): \"web\" tiene que empezar por https://") }
    }
}

func comprobar(_ personas: [Persona], _ archivo: String, errores: inout [String]) {
    for (i, p) in personas.enumerated() {
        for (campo, valor) in [("nombre", p.nombre), ("rol", p.rol), ("foto", p.foto), ("bio", p.bio)]
        where valor.trimmingCharacters(in: .whitespaces).isEmpty {
            errores.append("\(archivo) #\(i + 1): \"\(campo)\" está vacío")
        }
        for (campo, valor) in [("x", p.x), ("linkedin", p.linkedin), ("web", p.web)] {
            if let valor, !valor.hasPrefix("https://") { errores.append("\(archivo) #\(i + 1): \"\(campo)\" tiene que empezar por https://") }
        }
        if !FileManager.default.fileExists(atPath: raiz.appending(path: p.foto).path) {
            errores.append("\(archivo) #\(i + 1): no existe la foto \(p.foto)")
        }
    }
}

/// La fecha tiene que llevar zona horaria (+01:00 en invierno, +02:00 en verano), o cada navegador la leería a su manera.
func fecha(_ texto: String) -> Date? {
    guard texto.contains(try! Regex(#"(Z|[+-]\d\d:\d\d)$"#)) else { return nil }
    return try? Date(texto, strategy: .iso8601)
}

func comprobar(_ quedadas: [Quedada], errores: inout [String]) {
    for (i, q) in quedadas.enumerated() {
        if fecha(q.fecha) == nil { errores.append("quedadas.json #\(i + 1): la fecha necesita zona horaria, p. ej. 2026-11-19T19:00:00+01:00") }
        if q.titulo.trimmingCharacters(in: .whitespaces).isEmpty { errores.append("quedadas.json #\(i + 1): \"titulo\" está vacío") }
        if !(1...3).contains(q.charlas.count) { errores.append("quedadas.json #\(i + 1): tiene que tener de 1 a 3 charlas y tiene \(q.charlas.count)") }
        for (j, c) in q.charlas.enumerated() {
            let donde = "quedadas.json #\(i + 1), charla \(j + 1)"
            if c.titulo.trimmingCharacters(in: .whitespaces).isEmpty { errores.append("\(donde): \"titulo\" está vacío") }
            if (c.ponentes?.count ?? 0) > 3 { errores.append("\(donde): como mucho 3 ponentes") }
            for (k, p) in (c.ponentes ?? []).enumerated() {
                if p.nombre.trimmingCharacters(in: .whitespaces).isEmpty { errores.append("\(donde), ponente \(k + 1): \"nombre\" está vacío") }
                if let foto = p.foto, !FileManager.default.fileExists(atPath: raiz.appending(path: foto).path) {
                    errores.append("\(donde), ponente \(k + 1): no existe la foto \(foto)")
                }
            }
            if let tipo = c.tipo, tipo != "Taller" { errores.append("\(donde): \"tipo\" solo puede ser \"Taller\" (si es una charla, no se pone)") }
        }
    }
}

// MARK: - Tarjetas

let iconos = [
    "x": #"<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="currentColor" d="M12.2 1.5h2.2L9.6 7l5.6 7.5h-4.4L7.3 10l-4 4.5H1.1L6.2 8.6.8 1.5h4.5l3.1 4.2 3.8-4.2Zm-.8 11.7h1.2L4.7 2.7H3.4l8 10.5Z"/></svg>"#,
    "linkedin": #"<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="currentColor" d="M3.6 5.6H1V15h2.6V5.6ZM2.3 1.2a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3ZM15 9.8c0-2.5-.6-4.4-3.5-4.4-1.4 0-2.3.8-2.7 1.5V5.6H6.3V15h2.6v-4.6c0-1.2.2-2.4 1.8-2.4 1.5 0 1.5 1.4 1.5 2.5V15H15V9.8Z"/></svg>"#,
    "web": #"<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" d="M6.5 9.5l3-3M7 4.5l1-1a2.8 2.8 0 0 1 4 4l-1 1M9 11.5l-1 1a2.8 2.8 0 0 1-4-4l1-1"/></svg>"#,
]
let iconoMas = #"<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M8 3v10M3 8h10" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>"#
let meses = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

/// Igual que el esc() del script de la página.
func esc(_ t: String) -> String {
    t.replacing("&", with: "&amp;").replacing("<", with: "&lt;").replacing(">", with: "&gt;").replacing("\"", with: "&quot;")
}

func foto(_ p: Persona) -> String {
    #"<img class="foto" src="\#(esc(p.foto))" alt="\#(esc(p.nombre))" width="800" height="1000" loading="lazy">"#
}

func datos(_ p: Persona) -> String {
    // el texto tras "en" lo usa la ficha del embajador para la etiqueta del botón
    let redes = [("x", p.x, "X"), ("linkedin", p.linkedin, "LinkedIn"), ("web", p.web, "su web")].compactMap { clave, url, red in
        url.map { #"<a href="\#(esc($0))" target="_blank" rel="noopener me" aria-label="\#(esc(p.nombre)) en \#(red)">\#(iconos[clave]!)</a>"# }
    }.joined()
    return #"<div class="datos"><div><h3>\#(esc(p.nombre))</h3><p class="rol">\#(esc(p.rol))</p></div><p class="redes">\#(redes)</p></div>"#
}

func founder(_ p: Persona) -> String {
    #"""
    <article class="persona founder reveal">
      <div class="retrato">\#(foto(p))</div>
      \#(datos(p))
      <p class="bio-f">\#(esc(p.bio))</p>
    </article>
    """#
}

func embajador(_ p: Persona, _ i: Int) -> String {
    let mas = #"<button class="mas" type="button" aria-expanded="false" aria-controls="bio-\#(i)" aria-label="Leer sobre \#(esc(p.nombre))">\#(iconoMas)</button>"#
        + #"<div class="bio" id="bio-\#(i)"><p>\#(esc(p.bio))</p></div>"#
    return #"""
    <article class="persona reveal">
      <div class="retrato">\#(foto(p))\#(mas)</div>
      \#(datos(p))
    </article>
    """#
}

/// De las que ya pasaron solo se enseñan las más recientes (igual que en el script de la página).
let pasadas = 3

/// "Charla", "3 charlas", "Taller" o "2 charlas y 1 taller", según lo que traiga la quedada.
func categoria(_ q: Quedada) -> String {
    let talleres = q.charlas.filter(\.esTaller).count, charlas = q.charlas.count - talleres
    func cuenta(_ n: Int, _ uno: String, _ varios: String) -> String { n == 1 ? "1 \(uno)" : "\(n) \(varios)" }
    if talleres == 0 { return charlas == 1 ? "Charla" : cuenta(charlas, "charla", "charlas") }
    if charlas == 0 { return talleres == 1 ? "Taller" : cuenta(talleres, "taller", "talleres") }
    return "\(cuenta(charlas, "charla", "charlas")) y \(cuenta(talleres, "taller", "talleres"))"
}

/// "Ana", "Ana y Pol", "Ana, Pol y Asier", con "e" delante de i- e hi- ("Pol e Íñigo", pero "Ana y Hielo"): la misma regla que listaEs() en la página.
func ponentes(_ c: Charla) -> String {
    guard let nombres = c.ponentes?.map(\.nombre), let ultimo = nombres.last else { return "Ponente por confirmar" }
    if nombres.count == 1 { return ultimo }
    let inicio = ultimo.lowercased().folding(options: .diacriticInsensitive, locale: nil)
    let e = (inicio.hasPrefix("i") || inicio.hasPrefix("hi")) && !["hia", "hie", "hio", "hiu"].contains(where: inicio.hasPrefix)
    return nombres.dropLast().joined(separator: ", ") + (e ? " e " : " y ") + ultimo
}

/// "JO" de "Jon Ander Orcera": la primera letra del nombre y la del último apellido.
func iniciales(_ nombre: String) -> String {
    let partes = nombre.split(separator: " ")
    let elegidas = partes.count > 1 ? [partes.first!, partes.last!] : partes
    return elegidas.compactMap { $0.first.map(String.init) }.joined().uppercased()
}

/// La pila de caras de una charla, igual que caras() en la página.
func caras(_ c: Charla) -> String {
    let dentro = c.ponentes.flatMap { $0.isEmpty ? nil : $0 }.map { lista in
        lista.map { p in p.foto.map { #"<img src="\#(esc($0))" alt="" loading="lazy">"# } ?? "<i>\(esc(iniciales(p.nombre)))</i>" }.joined()
    } ?? "<i></i>"
    return #"<span class="caras" aria-hidden="true">\#(dentro)</span>"#
}

/// Las mismas tarjetas que pinta el script de la página. «El próximo» y «Ya pasó» salen del día en que se genera;
/// la página los vuelve a calcular al cargar, con la fecha de quien la visita.
/// Una quedada pasa a «Ya pasó» al día siguiente (hora de Madrid), no al empezar: todo su día sigue siendo «El próximo».
func tarjetas(_ quedadas: [Quedada], ahora: Date) -> String {
    if quedadas.isEmpty {
        return #"""
        <article class="evento vacio reveal"><img src="assets/img/glifos/arroba.webp" alt="" aria-hidden="true">
          <h3>Las primeras quedadas, muy pronto.</h3><p>Estamos preparando las primeras charlas. Apúntate y te avisamos de cada una.</p>
          <button class="btn" type="button" data-abre-apunte>Avísame</button></article>
        <div class="evento hueco reveal" aria-hidden="true">Próxima quedada</div>
        <div class="evento hueco reveal" aria-hidden="true">Próxima quedada</div>
        """#
    }
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = madrid
    let dia = { (d: Date) -> String in
        let c = calendario.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    // en orden de fecha: primero las últimas que ya pasaron y luego las que vienen
    let todas = quedadas.enumerated().map { i, q in
        let d = fecha(q.fecha)!
        return (i: i, q: q, d: d, pasado: dia(d) < dia(ahora))
    }.sorted { $0.d < $1.d }
    let lista = todas.filter { $0.pasado }.suffix(pasadas) + todas.filter { !$0.pasado }
    var visto = false
    return lista.map { i, q, d, pasado in
        let proximo = !pasado && !visto
        if proximo { visto = true }
        let c = calendario.dateComponents([.day, .month, .hour, .minute], from: d)
        let hora = String(format: "%02d:%02d", c.hour!, c.minute!)
        let clases = "evento reveal" + (pasado ? " pasado" : "") + (proximo ? " proximo" : "")
        let donde = "\(categoria(q)) · \(hora) (Madrid)" + (pasado ? "" : #"<span class="en-discord"> · Discord</span>"#)   // en las filas compactas del móvil no cabe
        let prox = proximo ? #"<span class="estado">El próximo</span>"# : pasado ? #"<span class="estado">Ya pasó</span>"# : ""
        let charlas = q.charlas.map { #"<li>\#(caras($0))<div><b>\#(esc($0.titulo))</b><span>\#(esc(ponentes($0)))</span></div></li>"# }.joined()
        let anchoCaras = max(1, q.charlas.map { $0.ponentes?.count ?? 0 }.max() ?? 0)   // la pila más ancha de la tarjeta
        let ejemplo = q.demo == true ? #"<span class="ejemplo">Ejemplo</span>"# : ""
        return #"""
        <article class="\#(clases)">
          \#(prox)<p class="dia">\#(c.day!)</p><p class="mes">\#(meses[c.month! - 1])</p>
          <h3>\#(esc(q.titulo))</h3>
          <ul class="charlas" style="--caras:\#(anchoCaras)">\#(charlas)</ul>
          <span class="donde">\#(donde)</span>\#(ejemplo)
          <button class="cubre" type="button" data-evento="\#(i)" aria-haspopup="dialog" aria-label="Ver \#(esc(q.titulo))"></button></article>
        """#
    }.joined(separator: "\n")
}

/// El JSON tal cual, para que la página repinte las tarjetas con la fecha del día en que se visita.
func datosQuedadas() throws -> String {
    let json = try String(contentsOf: raiz.appending(path: "datos/quedadas.json"), encoding: .utf8)
    return "<script type=\"application/json\" id=\"quedadas-datos\">\n"
        + json.trimmingCharacters(in: .whitespacesAndNewlines).replacing("</", with: "<\\/") + "\n</script>"
}

/// El muro de patrocinio: los logos, luego «Tu marca aquí» (siempre, para la siguiente) y huecos vacíos
/// hasta completar filas de 3, con 6 celdas como mínimo para que el muro no se quede cojo.
func muro(_ marcas: [Patrocinador]) -> String {
    let logos = marcas.map { m in
        let img = #"<img src="\#(esc(m.logo))" alt="\#(esc(m.nombre))" loading="lazy">"#
        return m.web.map { #"<a class="logo" href="\#(esc($0))" target="_blank" rel="noopener sponsored">\#(img)</a>"# }
            ?? #"<span class="logo">\#(img)</span>"#
    }
    let celdas = max(6, (marcas.count + 1 + 2) / 3 * 3)
    let huecos = Array(repeating: #"<span class="logo-hueco" aria-hidden="true"></span>"#, count: celdas - marcas.count - 1)
    return (logos + [#"<span class="logo-hueco primero" aria-hidden="true">Tu marca aquí</span>"#] + huecos).joined()
}

// MARK: - Marcas

enum Fallo: Error, CustomStringConvertible {
    case marcas(String, Int)
    var description: String {
        switch self { case let .marcas(nombre, n): "index.html: tiene que haber un par de marcas generado:\(nombre) y hay \(n)" }
    }
}

/// Sustituye lo que hay entre las marcas de `nombre`, con la misma sangría que tiene la marca de apertura.
func rellenar(_ html: String, _ nombre: String, _ contenido: String) throws -> String {
    let abre = "<!-- generado:\(nombre) ", cierra = "<!-- /generado:\(nombre) -->"
    let aperturas = html.ranges(of: abre)
    guard aperturas.count == 1, let inicio = aperturas.first,
          let finAbre = html[inicio.upperBound...].firstRange(of: "-->\n"),
          let fin = html[finAbre.upperBound...].firstRange(of: cierra) else {
        throw Fallo.marcas(nombre, html.ranges(of: abre).count)
    }
    let linea = html[..<inicio.lowerBound].lastIndex(of: "\n").map(html.index(after:)) ?? html.startIndex
    let sangria = String(html[linea..<inicio.lowerBound])
    let cuerpo = contenido.split(separator: "\n", omittingEmptySubsequences: false)
        .map { $0.isEmpty ? "\n" : sangria + $0 + "\n" }.joined()
    return String(html[..<finAbre.upperBound]) + cuerpo + sangria + String(html[fin.lowerBound...])
}

/// Para --comprobar: las tarjetas de quedadas (cuáles salen, en qué orden, «El próximo», «Ya pasó») dependen del día en que
/// se generó, y la página las repinta al cargar. Se comparan los datos de #quedadas-datos, que sí tienen que estar al día.
func sinEstado(_ html: String) -> String {
    html.replacing(try! Regex(#"<!-- generado:quedadas .*?<!-- /generado:quedadas -->"#).dotMatchesNewlines(), with: "")
}

// MARK: - Programa

let soloComprobar = CommandLine.arguments.contains("--comprobar")
var errores: [String] = []
let founders: [Persona] = leer("founders.json", campos: camposPersona, errores: &errores)
let embajadores: [Persona] = leer("embajadores.json", campos: camposPersona, errores: &errores)
let quedadas: [Quedada] = leer("quedadas.json", campos: camposQuedada, charlas: camposCharla, errores: &errores)
let patrocinadores: [Patrocinador] = leer("patrocinadores.json", campos: camposPatrocinador, errores: &errores)
comprobar(founders, "founders.json", errores: &errores)
comprobar(embajadores, "embajadores.json", errores: &errores)
comprobar(quedadas, errores: &errores)
comprobar(patrocinadores, errores: &errores)
if !errores.isEmpty {
    print(errores.joined(separator: "\n"))
    exit(1)
}

do {
    let actual = try String(contentsOf: pagina, encoding: .utf8)
    var nueva = try rellenar(actual, "founders", founders.map(founder).joined(separator: "\n"))
    nueva = try rellenar(nueva, "embajadores", embajadores.enumerated().map { embajador($1, $0) }.joined(separator: "\n"))
    nueva = try rellenar(nueva, "quedadas", tarjetas(quedadas, ahora: .now))
    nueva = try rellenar(nueva, "quedadas-datos", datosQuedadas())
    nueva = try rellenar(nueva, "patrocinadores", muro(patrocinadores))

    if soloComprobar {
        guard sinEstado(nueva) == sinEstado(actual) else {
            print("index.html no está al día con datos/*.json: pasa swift scripts/generar.swift")
            exit(1)
        }
        print("datos/ correcto e index.html al día")
    } else if nueva == actual {
        print("index.html ya estaba al día")
    } else {
        try nueva.write(to: pagina, atomically: true, encoding: .utf8)
        print("index.html actualizado")
    }
} catch {
    print(error)
    exit(1)
}
