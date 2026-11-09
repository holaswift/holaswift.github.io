enum Failure: Error, CustomStringConvertible {
    case markCount(String, Int)
    var description: String {
        switch self { case let .markCount(name, n): "index.html: tiene que haber un par de marcas generated:\(name) y hay \(n)" }
    }
}
