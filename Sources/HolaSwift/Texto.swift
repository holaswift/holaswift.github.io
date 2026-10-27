let blancos: [Unicode.Scalar] = [" ", "\t", "\n", "\r", "\u{0B}", "\u{0C}", "\u{A0}", "\u{2028}", "\u{2029}", "\u{FEFF}", "\u{3000}"]

func esBlanco(_ c: Unicode.Scalar) -> Bool { blancos.contains(c) || (c.value >= 0x2000 && c.value <= 0x200A) }

public func recortar(_ t: String) -> String {
    let letras = Array(t.unicodeScalars)
    guard let inicio = letras.firstIndex(where: { !esBlanco($0) }), let fin = letras.lastIndex(where: { !esBlanco($0) }) else { return "" }
    var s = ""
    for c in letras[inicio...fin] { s.unicodeScalars.append(c) }
    return s
}

/// Lo mismo que la página comprobaba con /^[^@\s]+@[^@\s]+\.[^@\s]{2,}$/.
public func esEmail(_ t: String) -> Bool {
    let letras = Array(t.unicodeScalars)
    guard !letras.contains(where: esBlanco), letras.filter({ $0 == "@" }).count == 1, let arroba = letras.firstIndex(of: "@") else { return false }
    let usuario = letras[..<arroba], dominio = Array(letras[(arroba + 1)...])
    guard !usuario.isEmpty else { return false }
    return dominio.indices.contains { i in dominio[i] == "." && i >= 1 && dominio.count - i - 1 >= 2 }
}
