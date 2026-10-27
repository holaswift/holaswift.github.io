// Comprueba datos/*.json y escribe con ellos el equipo, las quedadas y los patrocinadores en index.html.
//
// Solo toca lo que hay entre cada par de marcas:
//     <!-- generado:NOMBRE … -->
//     <!-- /generado:NOMBRE -->
// El resto de la página no se toca, y pasarlo dos veces da lo mismo.
//
// Uso, desde la raíz del repo:
//     swift run generar              comprueba los datos y escribe index.html
//     swift run generar --comprobar  solo comprueba: que los datos están bien y que index.html está al día

import Foundation
import HolaSwift

let raiz = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()   // Sources/Generar/main.swift
let pagina = raiz.appending(path: "index.html")
let madrid = TimeZone(identifier: "Europe/Madrid")!

// MARK: - Leer y comprobar

let camposPersona: Set = ["nombre", "rol", "foto", "bio", "x", "linkedin", "web"]
let camposQuedada: Set = ["fecha", "titulo", "notas", "enlace", "demo", "charlas"]
let camposCharla: Set = ["titulo", "ponentes", "tipo", "descripcion"]
let camposPonente: Set = ["nombre", "foto"]
let camposPatrocinador: Set = ["nombre", "logo", "web"]

func leer<T: Decodable>(_ archivo: String, campos: Set<String>, charlas: Set<String> = [], errores: inout [String]) -> [T] {
    guard let datos = try? Data(contentsOf: raiz.appending(path: "datos/\(archivo)")) else {
        errores.append("\(archivo): no se encuentra"); return []
    }
    guard let lista = try? JSONSerialization.jsonObject(with: datos) as? [[String: Any]] else {
        errores.append("\(archivo): no es un JSON válido o no es una lista [ … ] (revisa comas y comillas)"); return []
    }
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

func momento(_ d: Date) -> Momento {
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = madrid
    let c = calendario.dateComponents([.year, .month, .day, .hour, .minute], from: d)
    return Momento(ms: d.timeIntervalSince1970 * 1000, anio: c.year!, mes: c.month!, dia: c.day!, hora: c.hour!, minuto: c.minute!)
}

// MARK: - Equipo y patrocinio (solo los escribe el generador)

let iconos = [
    "x": #"<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="currentColor" d="M12.2 1.5h2.2L9.6 7l5.6 7.5h-4.4L7.3 10l-4 4.5H1.1L6.2 8.6.8 1.5h4.5l3.1 4.2 3.8-4.2Zm-.8 11.7h1.2L4.7 2.7H3.4l8 10.5Z"/></svg>"#,
    "linkedin": #"<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="currentColor" d="M3.6 5.6H1V15h2.6V5.6ZM2.3 1.2a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3ZM15 9.8c0-2.5-.6-4.4-3.5-4.4-1.4 0-2.3.8-2.7 1.5V5.6H6.3V15h2.6v-4.6c0-1.2.2-2.4 1.8-2.4 1.5 0 1.5 1.4 1.5 2.5V15H15V9.8Z"/></svg>"#,
    "web": #"<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" d="M6.5 9.5l3-3M7 4.5l1-1a2.8 2.8 0 0 1 4 4l-1 1M9 11.5l-1 1a2.8 2.8 0 0 1-4-4l1-1"/></svg>"#,
]
let iconoMas = #"<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M8 3v10M3 8h10" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>"#

func foto(_ p: Persona) -> String {
    #"<img class="foto" src="\#(esc(p.foto))" alt="\#(esc(p.nombre))" width="800" height="1000" loading="lazy">"#
}

func datos(_ p: Persona) -> String {
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
    let momentos = quedadas.map { momento(fecha($0.fecha)!) }
    var nueva = try rellenar(actual, "founders", founders.map(founder).joined(separator: "\n"))
    nueva = try rellenar(nueva, "embajadores", embajadores.enumerated().map { embajador($1, $0) }.joined(separator: "\n"))
    nueva = try rellenar(nueva, "quedadas", tarjetas(quedadas, momentos: momentos, hoy: momento(.now)))
    nueva = try rellenar(nueva, "quedadas-datos", datosQuedadas())
    nueva = try rellenar(nueva, "patrocinadores", muro(patrocinadores))

    if soloComprobar {
        guard sinEstado(nueva) == sinEstado(actual) else {
            print("index.html no está al día con datos/*.json: pasa swift run generar")
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
