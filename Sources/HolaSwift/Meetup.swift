/// One monthly session, as listed in `data/meetups.json`.
public struct Meetup {
    public let date: String
    /// `nil` while the theme isn't announced; the session shows a spoiler instead.
    public let title: String?
    public let notes, link: String?
    public let demo: Bool?
    /// Adds one more place on the bill (“Podrías ser tú”) to invite someone else to speak.
    public let openSlot: Bool?
    public let talks: [Talk]
    public var shownTitle: String { title ?? "Muy pronto" }

    public init(date: String, title: String?, notes: String?, link: String?, demo: Bool?, openSlot: Bool? = nil, talks: [Talk]) {
        self.date = date; self.title = title; self.notes = notes; self.link = link; self.demo = demo; self.openSlot = openSlot; self.talks = talks
    }
}

#if !hasFeature(Embedded)
extension Meetup: Decodable {}
#endif
