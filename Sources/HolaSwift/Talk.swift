public struct Talk {
    /// `nil` while the topic isn't announced; the session shows a spoiler instead.
    public let title: String?
    public let speakers: [Speaker]?
    /// `summary` is one short line for the session ticket; `description` is the full text on the back of the card.
    public let type, description, summary: String?
    public var shownTitle: String { title ?? "Tema por desvelar" }
    public var isWorkshop: Bool { type.map { sameText($0, "workshop") } ?? false }

    public init(title: String?, speakers: [Speaker]?, type: String?, description: String?, summary: String? = nil) {
        self.title = title; self.speakers = speakers; self.type = type; self.description = description; self.summary = summary
    }
}

#if !hasFeature(Embedded)
extension Talk: Decodable {}
#endif
