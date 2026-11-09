public struct Sponsor {
    public let name, logo: String
    public let web: String?
}

#if !hasFeature(Embedded)
extension Sponsor: Decodable {}
#endif
