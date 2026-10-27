// Las quedadas: las tarjetas, los ponentes y la hoja de cada una. La usan el generador (para el HTML que se publica)
// y la página (para repintarlas con la fecha de quien la visita), así que las dos salen siempre iguales.
//
// La página es Embedded Swift: el texto se trata por escalares Unicode y no por Character, ni con lowercased()
// o uppercased(), que necesitan las tablas de Unicode y engordan mucho el .wasm.

public let pasadasVisibles = 3

let meses = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

public func esc(_ t: String) -> String {
    var s = ""
    for c in t.unicodeScalars {
        switch c {
        case "&": s += "&amp;"
        case "<": s += "&lt;"
        case ">": s += "&gt;"
        case "\"": s += "&quot;"
        default: s.unicodeScalars.append(c)
        }
    }
    return s
}

// MARK: - Mayúsculas y minúsculas, para los nombres

let minusculas: [Unicode.Scalar] = ["á", "é", "í", "ó", "ú", "ü", "ñ", "à", "è", "ì", "ò", "ù", "ï", "î", "ç"]
let mayusculas: [Unicode.Scalar] = ["Á", "É", "Í", "Ó", "Ú", "Ü", "Ñ", "À", "È", "Ì", "Ò", "Ù", "Ï", "Î", "Ç"]

func minuscula(_ c: Unicode.Scalar) -> Unicode.Scalar {
    if c >= "A" && c <= "Z" { return Unicode.Scalar(c.value + 32)! }
    if let i = mayusculas.firstIndex(of: c) { return minusculas[i] }
    return c
}

func mayuscula(_ c: Unicode.Scalar) -> Unicode.Scalar {
    if c >= "a" && c <= "z" { return Unicode.Scalar(c.value - 32)! }
    if let i = minusculas.firstIndex(of: c) { return mayusculas[i] }
    return c
}

public func mayusculaInicial(_ t: String) -> String {
    var s = ""
    for (i, c) in t.unicodeScalars.enumerated() { s.unicodeScalars.append(i == 0 ? mayuscula(c) : c) }
    return s
}

// MARK: - Quedadas

public func categoria(_ q: Quedada) -> String {
    let talleres = q.charlas.filter { $0.esTaller }.count, charlas = q.charlas.count - talleres
    func cuenta(_ n: Int, _ uno: String, _ varios: String) -> String { n == 1 ? "1 " + uno : "\(n) " + varios }
    if talleres == 0 { return charlas == 1 ? "Charla" : cuenta(charlas, "charla", "charlas") }
    if charlas == 0 { return talleres == 1 ? "Taller" : cuenta(talleres, "taller", "talleres") }
    return cuenta(charlas, "charla", "charlas") + " y " + cuenta(talleres, "taller", "talleres")
}

/// "Ana", "Ana y Pol", "Ana, Pol y Asier", con "e" delante de i- e hi- ("Pol e Íñigo", pero "Ana y Hielo").
public func ponentes(_ c: Charla) -> String {
    guard let lista = c.ponentes, let ultimo = lista.last?.nombre else { return "Ponente por confirmar" }
    if lista.count == 1 { return ultimo }
    let letras = Array(ultimo.unicodeScalars.prefix(3)).map(minuscula)
    let i: [Unicode.Scalar] = ["i", "í", "ì", "ï", "î"]
    let vocal: [Unicode.Scalar] = ["a", "e", "o", "u", "á", "é", "ó", "ú", "à", "è", "ò", "ù", "ü"]
    let letra = { (n: Int) -> Unicode.Scalar in n < letras.count ? letras[n] : " " }
    let e = i.contains(letra(0)) || (letra(0) == "h" && i.contains(letra(1)) && !vocal.contains(letra(2)))
    return lista.dropLast().map { $0.nombre }.joined(separator: ", ") + (e ? " e " : " y ") + ultimo
}

public func iniciales(_ nombre: String) -> String {
    var palabras: [Unicode.Scalar] = [], anterior: Unicode.Scalar = " "
    for c in nombre.unicodeScalars {
        if anterior == " " && c != " " { palabras.append(c) }
        anterior = c
    }
    var s = ""
    for c in palabras.count > 1 ? [palabras.first!, palabras.last!] : palabras { s.unicodeScalars.append(mayuscula(c)) }
    return s
}

public func caras(_ c: Charla) -> String {
    var dentro = "<i></i>"
    if let lista = c.ponentes, !lista.isEmpty {
        dentro = lista.map { p in
            if let foto = p.foto { return #"<img src=""# + esc(foto) + #"" alt="" loading="lazy">"# }
            return "<i>" + esc(iniciales(p.nombre)) + "</i>"
        }.joined()
    }
    return #"<span class="caras" aria-hidden="true">"# + dentro + "</span>"
}

/// Una quedada pasa a «Ya pasó» al día siguiente (hora de Madrid), no al empezar: todo su día sigue siendo «El próximo».
public func yaPaso(_ m: Momento, hoy: Momento) -> Bool { m.diaNumero < hoy.diaNumero }

/// `momentos[i]` es la fecha de `quedadas[i]`, y `data-evento` guarda ese índice para abrir su hoja.
public func tarjetas(_ quedadas: [Quedada], momentos: [Momento], hoy: Momento) -> String {
    if quedadas.isEmpty {
        return #"""
        <article class="evento vacio reveal"><img src="assets/img/glifos/arroba.webp" alt="" aria-hidden="true">
          <h3>Las primeras quedadas, muy pronto.</h3><p>Estamos preparando las primeras charlas. Apúntate y te avisamos de cada una.</p>
          <button class="btn" type="button" data-abre-apunte>Avísame</button></article>
        <div class="evento hueco reveal" aria-hidden="true">Próxima quedada</div>
        <div class="evento hueco reveal" aria-hidden="true">Próxima quedada</div>
        """#
    }
    let orden = quedadas.indices.sorted { momentos[$0].ms < momentos[$1].ms }
    let pasadas = orden.filter { yaPaso(momentos[$0], hoy: hoy) }, vienen = orden.filter { !yaPaso(momentos[$0], hoy: hoy) }
    var visto = false
    return (pasadas.suffix(pasadasVisibles) + vienen).map { i in
        let q = quedadas[i], m = momentos[i], pasado = yaPaso(m, hoy: hoy)
        let proximo = !pasado && !visto
        if proximo { visto = true }
        let clases = "evento reveal" + (pasado ? " pasado" : "") + (proximo ? " proximo" : "")
        let donde = categoria(q) + " · " + m.horaMinuto + " (Madrid)" + (pasado ? "" : #"<span class="en-discord"> · Discord</span>"#)
        let estado = proximo ? #"<span class="estado">El próximo</span>"# : pasado ? #"<span class="estado">Ya pasó</span>"# : ""
        let charlas = q.charlas.map { c in "<li>" + caras(c) + "<div><b>" + esc(c.titulo) + "</b><span>" + esc(ponentes(c)) + "</span></div></li>" }.joined()
        let anchoCaras = max(1, q.charlas.map { $0.ponentes?.count ?? 0 }.max() ?? 0)
        let ejemplo = q.demo == true ? #"<span class="ejemplo">Ejemplo</span>"# : ""
        return #"<article class=""# + clases + "\">\n"
            + "  " + estado + #"<p class="dia">\#(m.dia)</p><p class="mes">"# + meses[m.mes - 1] + "</p>\n"
            + "  <h3>" + esc(q.titulo) + "</h3>\n"
            + #"  <ul class="charlas" style="--caras:\#(anchoCaras)">"# + charlas + "</ul>\n"
            + #"  <span class="donde">"# + donde + "</span>" + ejemplo + "\n"
            + #"  <button class="cubre" type="button" data-evento="\#(i)" aria-haspopup="dialog" aria-label="Ver "# + esc(q.titulo) + #""></button></article>"#
    }.joined(separator: "\n")
}

public func charlasHoja(_ q: Quedada) -> String {
    q.charlas.map { c in
        #"<section class="cal-grupo cal-charla"><p class="cal-et">"# + (c.esTaller ? "Taller" : "Charla") + "</p>"
            + #"<div class="cal-quienes">"# + caras(c) + "<div><h4>" + esc(c.titulo) + #"</h4><p class="cal-quien">"# + esc(ponentes(c)) + "</p></div></div>"
            + (c.descripcion.map { #"<p class="cal-desc">"# + esc($0) + "</p>" } ?? "") + "</section>"
    }.joined()
}

/// En «Añadir a Calendario»: 20 minutos por charla y 15 de bienvenida y preguntas.
public func minutos(_ q: Quedada) -> Int { q.charlas.count * 20 + 15 }

public func descripcionCalendario(_ q: Quedada) -> String {
    q.charlas.map { c in (c.esTaller ? "Taller: " : "Charla: ") + c.titulo + " (" + ponentes(c) + ")" }.joined(separator: "\n")
        + (q.notas.map { "\n\n" + $0 } ?? "")
}

public func textoCalendario(_ t: String) -> String {
    var s = ""
    for c in t.unicodeScalars {
        switch c {
        case "\\", ",", ";": s += "\\"; s.unicodeScalars.append(c)
        case "\n": s += "\\n"
        default: s.unicodeScalars.append(c)
        }
    }
    return s
}
