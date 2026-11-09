// Text helpers shared by the generator and the page: speaker names and initials, and whether a session has passed.
//
// The page is Embedded Swift, so text is handled as Unicode scalars rather than Character, and without lowercased() or
// uppercased(): they need the Unicode tables and make the .wasm much bigger.

public let visiblePastCount = 3

let monthNames = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

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

// MARK: - Upper and lower case, for names

let lowerAccents: [Unicode.Scalar] = ["á", "é", "í", "ó", "ú", "ü", "ñ", "à", "è", "ì", "ò", "ù", "ï", "î", "ç"]
let upperAccents: [Unicode.Scalar] = ["Á", "É", "Í", "Ó", "Ú", "Ü", "Ñ", "À", "È", "Ì", "Ò", "Ù", "Ï", "Î", "Ç"]

func lower(_ c: Unicode.Scalar) -> Unicode.Scalar {
    if c >= "A" && c <= "Z" { return Unicode.Scalar(c.value + 32)! }
    if let i = upperAccents.firstIndex(of: c) { return lowerAccents[i] }
    return c
}

func upper(_ c: Unicode.Scalar) -> Unicode.Scalar {
    if c >= "a" && c <= "z" { return Unicode.Scalar(c.value - 32)! }
    if let i = lowerAccents.firstIndex(of: c) { return upperAccents[i] }
    return c
}

public func capitalized(_ t: String) -> String {
    var s = ""
    for (i, c) in t.unicodeScalars.enumerated() { s.unicodeScalars.append(i == 0 ? upper(c) : c) }
    return s
}

// MARK: - Meetups

/// Joins speaker names: "Ana", "Ana y Pol", "Ana, Pol y Asier".
///
/// Uses "e" before an i- or hi- sound ("Pol e Íñigo"), but not before hi + vowel ("Ana y Hielo").
public func speakers(_ c: Talk) -> String {
    guard let list = c.speakers, let last = list.last?.name else { return "Ponente por confirmar" }
    if list.count == 1 { return last }
    let scalars = Array(last.unicodeScalars.prefix(3)).map(lower)
    let i: [Unicode.Scalar] = ["i", "í", "ì", "ï", "î"]
    let vowels: [Unicode.Scalar] = ["a", "e", "o", "u", "á", "é", "ó", "ú", "à", "è", "ò", "ù", "ü"]
    let scalar = { (n: Int) -> Unicode.Scalar in n < scalars.count ? scalars[n] : " " }
    let e = i.contains(scalar(0)) || (scalar(0) == "h" && i.contains(scalar(1)) && !vowels.contains(scalar(2)))
    return list.dropLast().map { $0.name }.joined(separator: ", ") + (e ? " e " : " y ") + last
}

public func initials(_ name: String) -> String {
    var words: [Unicode.Scalar] = [], previous: Unicode.Scalar = " "
    for c in name.unicodeScalars {
        if previous == " " && c != " " { words.append(c) }
        previous = c
    }
    var s = ""
    for c in words.count > 1 ? [words.first!, words.last!] : words { s.unicodeScalars.append(upper(c)) }
    return s
}

/// A session counts as past from the next day (Spanish time), not when it starts, so it stays upcoming all day.
public func isPast(_ m: Moment, today: Moment) -> Bool { m.dayNumber < today.dayNumber }

/// The estimated length of a session: 20 minutes per talk (the open slot included) plus 15 for welcome and questions.
public func durationMinutes(_ q: Meetup) -> Int { (q.talks.count + (q.openSlot == true ? 1 : 0)) * 20 + 15 }
