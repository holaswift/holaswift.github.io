// The models for data/*.json. The generator decodes them with JSONDecoder; the page (Embedded Swift, no Codable)
// builds them field by field from JavaScript objects through their initializers.

public struct Person {
    public let name, role, photo, bio: String
    public let x, linkedin, web: String?
    /// A shorter name for the front of the card, so it fits on one line; the profile shows the full ``name``.
    public let shortName: String?
    /// A short personal line shown on the front of the ambassador card.
    public let quote: String?
    /// The year they joined, which sets the card series; `nil` means the founding series, ``foundingYear``.
    public let since: Int?

    public var year: Int { since ?? Person.foundingYear }
    public var cardName: String { shortName ?? name }
    public static let foundingYear = 2026
}

#if !hasFeature(Embedded)
extension Person: Decodable {}
#endif
