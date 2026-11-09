public struct Speaker {
    public let name: String
    public let photo: String?

    public init(name: String, photo: String?) { self.name = name; self.photo = photo }
}

#if !hasFeature(Embedded)
extension Speaker: Decodable {}
#endif
