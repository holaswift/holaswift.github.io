// Sessions (the monthly online event): one ticket per row; clicking one flies it to the centre and flips it to show the
// whole session. Both the generator and the page render this HTML, so they always come out the same.

let weekdayNames = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]

/// The day of the week, 0 being Sunday.
///
/// Sakamoto's method: ``Moment`` has no weekday, and this spares the page a call to `Intl`.
public func weekday(_ m: Moment) -> Int {
    let offsets = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
    let y = m.month < 3 ? m.year - 1 : m.year
    return (y + y / 4 - y / 100 + y / 400 + offsets[m.month - 1] + m.day) % 7
}

/// The public name, “Sesión de enero”; callers add the year where needed.
public func sessionName(_ m: Moment) -> String { "Sesión de " + monthNames[m.month - 1] }

/// The open card's note when the theme isn't out yet and there are no notes of its own.
public func sessionPendingNote(_ m: Moment) -> String {
    "Muy pronto vas a conocer las presentaciones de " + monthNames[m.month - 1] + " \(m.year). Apúntate y te avisamos en cuanto las anunciemos."
}

// MARK: - Countdown

/// The seven segments of a digit, as SVG polygons in a 12 × 20 box, in order a…g (a top, b and c right, d bottom,
/// e and f left, g middle).
///
/// Drawn instead of using a font so the 7 has only three segments (fonts add the top-left one and it reads as a 9) and
/// every digit can show its unlit segments faintly, like an LCD.
let segmentShapes: [String] = [
    "1.6,1.2 2.7,0.1 9.3,0.1 10.4,1.2 9.3,2.3 2.7,2.3",
    "10.9,1.6 12,2.7 12,8.5 10.9,9.6 9.8,8.5 9.8,2.7",
    "10.9,10.4 12,11.5 12,17.3 10.9,18.4 9.8,17.3 9.8,11.5",
    "1.6,18.8 2.7,17.7 9.3,17.7 10.4,18.8 9.3,19.9 2.7,19.9",
    "1.1,10.4 2.2,11.5 2.2,17.3 1.1,18.4 0,17.3 0,11.5",
    "1.1,1.6 2.2,2.7 2.2,8.5 1.1,9.6 0,8.5 0,2.7",
    "1.6,10 2.7,8.9 9.3,8.9 10.4,10 9.3,11.1 2.7,11.1",
]
/// The indices into ``segmentShapes`` that each digit, 0…9, lights.
let segmentsOn: [[Int]] = [[0, 1, 2, 3, 4, 5], [1, 2], [0, 1, 6, 4, 3], [0, 1, 6, 2, 3], [5, 6, 1, 2], [0, 5, 6, 2, 3],
                           [0, 5, 6, 4, 3, 2], [0, 1, 2], [0, 1, 2, 3, 4, 5, 6], [0, 1, 2, 3, 5, 6]]

/// One seven-segment digit as SVG; `nil` draws it with every segment off.
func segmentDigit(_ n: Int?) -> String {
    #"<svg class="seg" viewBox="0 0 12 20" aria-hidden="true">"# + segmentShapes.enumerated().map { i, points in
        #"<polygon points=""# + points + #"""# + ((n.map { segmentsOn[$0].contains(i) } ?? false) ? #" class="on""# : "") + "/>"
    }.joined() + "</svg>"
}

let segmentColon = #"<svg class="seg colon" viewBox="0 0 4 20" aria-hidden="true"><rect class="on" x="1" y="5.4" width="2" height="2" rx=".4"/><rect class="on" x="1" y="12.6" width="2" height="2" rx=".4"/></svg>"#

/// The countdown to the next session, like the clock in *24*: “74:21:08:10” (days, hours, minutes, seconds), or
/// “03:12:45” on its last day.
///
/// From the start and for ``durationMinutes(_:)`` it says “En directo”; after that, “Ya pasó”. The digits are drawn
/// segments, with visually hidden text for screen readers. The page re-renders it every second.
/// - Parameters:
///   - now: The current time, in milliseconds since 1970.
///   - start: When the session starts, in milliseconds since 1970.
///   - minutes: How long the session counts as live.
public func countdown(from now: Double, to start: Double, minutes: Int) -> String {
    let left = Int((start - now) / 1000)
    if left <= 0 {
        return now < start + Double(minutes) * 60_000 ? #"<small class="live"><i aria-hidden="true"></i>En directo</small>"# : "<small>Ya pasó</small>"
    }
    let days = left / 86_400, h = left % 86_400 / 3600, min = left % 3600 / 60, s = left % 60
    let groups = (days > 0 ? [days] : []) + [h, min, s]
    let drawn = groups.map { n -> String in
        let text = twoDigits(n)
        return text.unicodeScalars.map { segmentDigit(Int($0.value) - 48) }.joined()
    }.joined(separator: segmentColon)
    let spoken = (days > 0 ? "\(days) " + (days == 1 ? "día" : "días") + ", " : "") + twoDigits(h) + ":" + twoDigits(min) + ":" + twoDigits(s)
    return drawn + #"<span class="visually-hidden">Faltan "# + spoken + "</span>"
}

/// The clock switched off: every segment unlit.
///
/// The generator writes this so that, until the Swift code starts, the page shows a display about to turn on rather than
/// a countdown frozen at the moment index.html was generated.
let countdownOff = Array(repeating: segmentDigit(nil) + segmentDigit(nil), count: 4).joined(separator:
    #"<svg class="seg colon" viewBox="0 0 4 20" aria-hidden="true"><rect x="1" y="5.4" width="2" height="2" rx=".4"/><rect x="1" y="12.6" width="2" height="2" rx=".4"/></svg>"#)

/// The countdown element, with the data the page needs to keep it ticking.
///
/// `data-at` is written as `Int64` because the page runs in wasm32, where `Int` is 32 bits and milliseconds don't fit.
/// - Parameter now: The visitor's time in milliseconds, or `nil` (the generator) to write the clock switched off.
public func countdownTag(_ q: Meetup, _ m: Moment, now: Double?) -> String {
    #"<span class="ticket-status countdown" role="timer" data-at="\#(Int64(m.ms))" data-minutes="\#(durationMinutes(q))">"#
        + (now.map { countdown(from: $0, to: m.ms, minutes: durationMinutes(q)) } ?? countdownOff) + "</span>"
}

/// The internal identifier, such as “2027-01”, used for the sign-up origin, files and links.
public func sessionId(_ m: Moment) -> String { "\(m.year)-" + twoDigits(m.month) }

/// “Sesión de enero 2027” with the brand's h icon: the label of the ticket and of the open card.
public func sessionKicker(_ m: Moment) -> String {
    #"<img class="kicker-h" src="assets/img/icono-h.svg" alt="" width="40" height="40">"# + sessionName(m) + " \(m.year)"
}

/// “Miércoles 20 de enero, 2027 a las 19:00 (hora de España)”
public func sessionLongDate(_ m: Moment) -> String {
    capitalized(weekdayNames[weekday(m)]) + " \(m.day) de " + monthNames[m.month - 1] + ", \(m.year) a las " + m.hourMinute + " (hora de España)"
}

/// “1 presentación”, “3 presentaciones”, “2 presentaciones y 1 taller”.
///
/// The open slot counts as a talk: the session is announced with all its places, even the one nobody has taken yet.
public func sessionCount(_ q: Meetup) -> String {
    let workshops = q.talks.filter { $0.isWorkshop }.count, talks = q.talks.count - workshops + (q.openSlot == true ? 1 : 0)
    func label(_ n: Int, _ one: String, _ many: String) -> String { "\(n) " + (n == 1 ? one : many) }
    if workshops == 0 { return label(talks, "presentación", "presentaciones") }
    if talks == 0 { return label(workshops, "taller", "talleres") }
    return label(talks, "presentación", "presentaciones") + " y " + label(workshops, "taller", "talleres")
}

func face(_ p: Speaker?) -> String {
    guard let p else { return #"<i class="ticket-face" aria-hidden="true"></i>"# }
    if let photo = p.photo { return #"<img class="ticket-face" src=""# + esc(photo) + #"" alt="" loading="lazy">"# }
    return #"<i class="ticket-face" aria-hidden="true">"# + esc(initials(p.name)) + "</i>"
}

/// A placeholder for text that isn't announced yet (a theme, a topic, a description), like SwiftUI's
/// `.redacted(reason: .placeholder)`.
/// - Parameters:
///   - widths: The width of each bar, as a percentage of the line.
///   - soon: Adds a “Próximamente” label after the last bar.
public func spoiler(_ widths: [Int], soon: Bool = false) -> String {
    let lines = widths.enumerated().map { i, w in
        let bar = #"<i style="width:\#(w)%"></i>"#
        return soon && i == widths.count - 1 ? #"<span class="spoiler-last">"# + bar + #"<b class="soon">Próximamente</b></span>"# : bar
    }.joined()
    return #"<span class="spoiler" role="img" aria-label="Próximamente">"# + lines + "</span>"
}

/// The open-slot invitation on the ticket (“Podrías ser tú”), shown when ``Meetup/openSlot`` is set.
let openSlotItem = #"<li class="open-slot"><i class="ticket-face" aria-hidden="true"></i><div><p class="ticket-speaker">Podrías ser tú</p>"#
    + #"<p class="ticket-talk">Tu presentación</p><p class="ticket-summary">Esta sesión tiene sitio para una presentación más. Si tienes algo que contar, escríbenos.</p></div></li>"#

/// The ticket's face: the same HTML in the row and on the front of the card that flies open.
public func ticket(_ q: Meetup, _ m: Moment, status: String?) -> String {
    let talks = q.talks.map { c in
        "<li>" + face(c.speakers?.first) + "<div>"
            + #"<p class="ticket-speaker">"# + esc(speakers(c)) + "</p>"
            + #"<p class="ticket-talk">"# + (c.title.map(esc) ?? spoiler([82])) + "</p>"
            + (c.summary.map { #"<p class="ticket-summary">"# + esc($0) + "</p>" } ?? (c.title == nil ? #"<p class="ticket-summary">"# + spoiler([96, 64]) + "</p>" : ""))
            + "</div></li>"
    }.joined() + (q.openSlot == true ? openSlotItem : "")
    let columns = q.talks.count + (q.openSlot == true ? 1 : 0)
    return #"<div class="ticket">"#
        + #"<div class="stub"><p class="stub-day">\#(m.day)</p>"#
        + #"<p class="stub-month">"# + monthNames[m.month - 1] + " \(m.year)</p>"
        + #"<p class="stub-time">"# + capitalized(weekdayNames[weekday(m)]) + "</p>"
        + #"<p class="stub-place">Online por Discord</p></div>"#
        + #"<div class="ticket-main"><div class="ticket-top"><p class="ticket-kicker">"# + sessionKicker(m) + "</p>"
        + (status ?? "") + "</div>"
        + #"<h3 class="ticket-title">"# + (q.title.map(esc) ?? spoiler([66, 38], soon: true)) + "</h3>"
        + #"<ul class="ticket-talks" style="--talks:\#(columns)">"# + talks + "</ul>"
        + #"<p class="ticket-foot"><span>"# + sessionCount(q) + " a las " + m.hourMinute + #" (España)</span><span class="ticket-more">Ver la sesión</span></p>"#
        + "</div></div>"
}

let sessionStickers = ["mano", "destello", "arroba", "corazon", "llaves", "enye", "codigo", "pregunta"]

let pegSpots: [(left: Int, leftTurn: Int, right: Int, rightTurn: Int)] = [(30, -14, 68, 12), (70, -8, 28, 16), (44, -18, 76, 8), (24, -10, 52, 18), (62, -16, 34, 10)]

/// Consecutive sessions never share a sticker.
func sessionPegs(_ index: Int) -> String {
    let n = sessionStickers.count, spot = pegSpots[index % pegSpots.count]
    return [("l", sessionStickers[index * 3 % n], spot.left, spot.leftTurn), ("r", sessionStickers[(index * 3 + 4) % n], spot.right, spot.rightTurn)]
        .map { side, name, y, turn in
            #"<img class="session-peg \#(side)" src="assets/img/pegatinas/\#(name).webp" alt="" aria-hidden="true" loading="lazy" style="--y:\#(y)%;--r:\#(turn)deg">"#
        }.joined()
}

/// One row per session: the last ``visiblePastCount`` past ones and every upcoming one, in date order.
///
/// Only the next session gets the large ticket and the countdown; the rest are compact, with their details on the card.
/// Each row's `data-session` is its index in `meetups`, which the page uses to open it.
/// - Parameter clockOn: `false` (the generator) writes the next session's clock switched off.
public func sessionRows(_ meetups: [Meetup], moments: [Moment], today: Moment, clockOn: Bool = true) -> String {
    if meetups.isEmpty {
        return #"<p class="sessions-empty reveal">Estamos preparando las primeras sesiones. Apúntate y te avisamos de cada una.</p>"#
    }
    let order = meetups.indices.sorted { moments[$0].ms < moments[$1].ms }
    let past = order.filter { isPast(moments[$0], today: today) }, upcoming = order.filter { !isPast(moments[$0], today: today) }
    var seen = false
    return (past.suffix(visiblePastCount) + upcoming).map { i in
        let q = meetups[i], m = moments[i], isPastSession = isPast(m, today: today)
        let isNext = !isPastSession && !seen
        if isNext { seen = true }
        let status: String? = isNext ? countdownTag(q, m, now: clockOn ? today.ms : nil) : isPastSession ? #"<span class="ticket-status">Ya pasó</span>"# : nil
        let classes = "session reveal" + (isPastSession ? " past" : "") + (isNext ? " next" : " compact")
        return #"<article class=""# + classes + #"" data-session="\#(i)">"# + sessionPegs(i) + ticket(q, m, status: status)
            + #"<button class="open-session" type="button" aria-haspopup="dialog" aria-label="Ver la "# + esc(sessionName(m)) + (q.title.map { ": " + esc($0) } ?? "") + #""></button></article>"#
    }.joined(separator: "\n")
}

/// The back of the card: every talk with its full description, side by side so the whole session fits without scrolling.
public func sessionBackTalks(_ q: Meetup) -> String {
    q.talks.map { c in
        #"<section class="sb-talk"><div class="sb-who">"# + face(c.speakers?.first)
            + #"<div><p class="ticket-speaker">"# + esc(speakers(c)) + "</p><h4>" + (c.title.map(esc) ?? spoiler([74])) + "</h4></div></div>"
            + #"<p class="sb-desc">"# + ((c.description ?? c.summary).map(esc) ?? spoiler([100, 92, 58])) + "</p></section>"
    }.joined() + (q.openSlot == true
        ? #"<section class="sb-talk open-slot"><div class="sb-who"><i class="ticket-face" aria-hidden="true"></i><div><p class="ticket-speaker">Podrías ser tú</p><h4>Tu presentación</h4></div></div>"#
            + #"<p class="sb-desc">Esta sesión tiene sitio para una presentación más. Si tienes algo que contar, por pequeño que te parezca, escríbenos y compártelo con la comunidad.</p></section>"#
        : "")
}
