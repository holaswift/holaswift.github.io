import HolaSwift
import JavaScriptKit

/// Writes a value to the page only when it changes, to cross into JavaScript as little as possible.
final class Cached<T> {
    private var last: T? = nil
    private let equal: (T, T) -> Bool, setter: (T) -> Void
    init(equal: @escaping (T, T) -> Bool, _ setter: @escaping (T) -> Void) { self.equal = equal; self.setter = setter }
    func set(_ v: T) {
        if let last, equal(last, v) { return }
        last = v; setter(v)
    }
}

extension Cached where T == Double { convenience init(_ setter: @escaping (Double) -> Void) { self.init(equal: { $0 == $1 }, setter) } }
extension Cached where T == Bool { convenience init(_ setter: @escaping (Bool) -> Void) { self.init(equal: { $0 == $1 }, setter) } }
/// Compares with ``sameText(_:_:)``: `==` on `String` would pull the Unicode tables into the .wasm.
extension Cached where T == String { convenience init(_ setter: @escaping (String) -> Void) { self.init(equal: sameText, setter) } }
