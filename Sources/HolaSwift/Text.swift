let whitespaceScalars: [Unicode.Scalar] = [" ", "\t", "\n", "\r", "\u{0B}", "\u{0C}", "\u{A0}", "\u{2028}", "\u{2029}", "\u{FEFF}", "\u{3000}"]

func isWhitespace(_ c: Unicode.Scalar) -> Bool { whitespaceScalars.contains(c) || (c.value >= 0x2000 && c.value <= 0x200A) }

public func trimmed(_ t: String) -> String {
    let scalars = Array(t.unicodeScalars)
    guard let start = scalars.firstIndex(where: { !isWhitespace($0) }), let end = scalars.lastIndex(where: { !isWhitespace($0) }) else { return "" }
    var s = ""
    for c in scalars[start...end] { s.unicodeScalars.append(c) }
    return s
}

/// Mirrors the regex the page used before Swift: `/^[^@\s]+@[^@\s]+\.[^@\s]{2,}$/`.
public func isEmail(_ t: String) -> Bool {
    let scalars = Array(t.unicodeScalars)
    guard !scalars.contains(where: isWhitespace), scalars.filter({ $0 == "@" }).count == 1, let atIndex = scalars.firstIndex(of: "@") else { return false }
    let user = scalars[..<atIndex], domain = Array(scalars[(atIndex + 1)...])
    guard !user.isEmpty else { return false }
    return domain.indices.contains { i in domain[i] == "." && i >= 1 && domain.count - i - 1 >= 2 }
}

/// Compares two strings byte by byte (UTF-8).
///
/// `==` on `String` applies Unicode normalization, which in Embedded Swift pulls its tables into the .wasm (about 700 KB).
/// Comparing against fixed words like "workshop" doesn't need it.
public func sameText(_ a: String, _ b: String) -> Bool { a.utf8.elementsEqual(b.utf8) }
