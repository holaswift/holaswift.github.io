// Validates data/*.json, writes the team, the sessions and the sponsors into index.html, and writes the sessions into
// sesiones.ics, the calendar people subscribe to.
//
// It only touches what sits between each pair of markers:
//     <!-- generated:NAME … -->
//     <!-- /generated:NAME -->
// The rest of the page is left alone, and running it twice gives the same result.
//
// Usage, from the repo root:
//     swift run generate           validates the data and writes index.html and sesiones.ics
//     swift run generate --check   only checks: that the data is valid and both files are up to date

import Foundation
import HolaSwift

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()   // Sources/Generate/main.swift
let page = root.appending(path: "index.html")
let madridTimeZone = TimeZone(identifier: "Europe/Madrid")!

// MARK: - Reading and validating

let personFields: Set = ["name", "shortName", "quote", "role", "photo", "bio", "x", "linkedin", "web", "since"]
let meetupFields: Set = ["date", "title", "notes", "link", "demo", "openSlot", "talks"]
let talkFields: Set = ["title", "speakers", "type", "description", "summary"]
let speakerFields: Set = ["name", "photo"]
let sponsorFields: Set = ["name", "logo", "web"]

/// Decodes a data file, reporting unknown fields as errors so a typo in a key doesn't go unnoticed.
func read<T: Decodable>(_ file: String, fields: Set<String>, talks: Set<String> = [], errors: inout [String]) -> [T] {
    guard let info = try? Data(contentsOf: root.appending(path: "data/\(file)")) else {
        errors.append("\(file): no se encuentra"); return []
    }
    guard let list = try? JSONSerialization.jsonObject(with: info) as? [[String: Any]] else {
        errors.append("\(file): no es un JSON válido o no es una lista [ … ] (revisa comas y comillas)"); return []
    }
    return list.enumerated().compactMap { i, item in
        let place = "\(file) #\(i + 1)"
        let unknown = Set(item.keys).subtracting(fields)
        if !unknown.isEmpty { errors.append("\(place): campos que la web no usa: \(unknown.sorted().joined(separator: ", "))") }
        for (j, talk) in ((item["talks"] as? [[String: Any]]) ?? []).enumerated() {
            let unknown = Set(talk.keys).subtracting(talks)
            if !unknown.isEmpty { errors.append("\(place), presentación \(j + 1): campos que la web no usa: \(unknown.sorted().joined(separator: ", "))") }
            for (k, speaker) in ((talk["speakers"] as? [Any]) ?? []).enumerated() {
                guard let speaker = speaker as? [String: Any] else {
                    errors.append("\(place), presentación \(j + 1), ponente \(k + 1): tiene que ser { \"name\": …, \"photo\": … }"); continue
                }
                let unknown = Set(speaker.keys).subtracting(speakerFields)
                if !unknown.isEmpty { errors.append("\(place), presentación \(j + 1), ponente \(k + 1): campos que la web no usa: \(unknown.sorted().joined(separator: ", "))") }
            }
        }
        do {
            return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: item))
        } catch let DecodingError.keyNotFound(key, _) {
            errors.append("\(place): falta \"\(key.stringValue)\"")
        } catch let DecodingError.typeMismatch(_, context), let DecodingError.valueNotFound(_, context) {
            errors.append("\(place): \"\(context.codingPath.last?.stringValue ?? "?")\" no tiene el tipo que toca (texto, número o true/false)")
        } catch {
            errors.append("\(place): \(error.localizedDescription)")
        }
        return nil
    }
}

/// How many sponsor stickers fit in the sponsorship section.
let maxSponsors = 5

func validate(_ sponsors: [Sponsor], errors: inout [String]) {
    if sponsors.count > maxSponsors { errors.append("sponsors.json: en patrocinio caben \(maxSponsors) patrocinadores y hay \(sponsors.count)") }
    for (i, m) in sponsors.enumerated() {
        let place = "sponsors.json #\(i + 1)"
        if m.name.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("\(place): \"name\" está vacío") }
        if !FileManager.default.fileExists(atPath: root.appending(path: m.logo).path) { errors.append("\(place): no existe el logo \(m.logo)") }
        if let web = m.web, !web.hasPrefix("https://") { errors.append("\(place): \"web\" tiene que empezar por https://") }
    }
}

func validate(_ people: [Person], _ file: String, errors: inout [String]) {
    for (i, p) in people.enumerated() {
        for (field, value) in [("name", p.name), ("role", p.role), ("photo", p.photo), ("bio", p.bio)]
        where value.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("\(file) #\(i + 1): \"\(field)\" está vacío")
        }
        for (field, value) in [("x", p.x), ("linkedin", p.linkedin), ("web", p.web)] {
            if let value, !value.hasPrefix("https://") { errors.append("\(file) #\(i + 1): \"\(field)\" tiene que empezar por https://") }
        }
        if let since = p.since, !(Person.foundingYear...2100).contains(since) {
            errors.append("\(file) #\(i + 1): \"since\" tiene que ser un año, de \(Person.foundingYear) en adelante")
        }
        if !FileManager.default.fileExists(atPath: root.appending(path: p.photo).path) {
            errors.append("\(file) #\(i + 1): no existe la foto \(p.photo)")
        } else if !FileManager.default.fileExists(atPath: root.appending(path: face(of: p)).path) {
            errors.append("\(file) #\(i + 1): falta \(face(of: p)) (se hace con swift scripts/caras.swift \(p.photo))")
        }
    }
}

/// Parses a session date, which must carry a time zone (+01:00 in winter, +02:00 in summer): without one, each browser
/// would read it its own way.
func date(_ text: String) -> Date? {
    guard text.contains(try! Regex(#"(Z|[+-]\d\d:\d\d)$"#)) else { return nil }
    return try? Date(text, strategy: .iso8601)
}

func validate(_ meetups: [Meetup], errors: inout [String]) {
    for (i, q) in meetups.enumerated() {
        if date(q.date) == nil { errors.append("meetups.json #\(i + 1): \"date\" necesita zona horaria, p. ej. 2026-11-19T19:00:00+01:00") }
        if let title = q.title, title.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("meetups.json #\(i + 1): \"title\" está vacío (si aún no hay tema, quítalo)") }
        if !(1...3).contains(q.talks.count) { errors.append("meetups.json #\(i + 1): tiene que tener de 1 a 3 presentaciones y tiene \(q.talks.count)") }
        for (j, c) in q.talks.enumerated() {
            let place = "meetups.json #\(i + 1), presentación \(j + 1)"
            if let title = c.title, title.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("\(place): \"title\" está vacío (si aún no hay tema, quítalo)") }
            if (c.speakers?.count ?? 0) > 3 { errors.append("\(place): como mucho 3 ponentes") }
            for (k, p) in (c.speakers ?? []).enumerated() {
                if p.name.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("\(place), ponente \(k + 1): \"name\" está vacío") }
                if let photo = p.photo, !photo.hasPrefix("assets/caras/") {
                    errors.append("\(place), ponente \(k + 1): la foto tiene que ser una cara de assets/caras/ (la de 800 × 1000 se rompe al achicarla)")
                } else if let photo = p.photo, !FileManager.default.fileExists(atPath: root.appending(path: photo).path) {
                    errors.append("\(place), ponente \(k + 1): no existe la foto \(photo)")
                }
            }
            if let type = c.type, type != "workshop" { errors.append("\(place): \"type\" solo puede ser \"workshop\" (si es una presentación, no se pone)") }
        }
    }
}

func moment(_ d: Date) -> Moment {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = madridTimeZone
    let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: d)
    return Moment(ms: d.timeIntervalSince1970 * 1000, year: c.year!, month: c.month!, day: c.day!, hour: c.hour!, minute: c.minute!)
}

// MARK: - Team and sponsorship (only the generator writes them)

let icons = [
    "x": #"<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="currentColor" d="M12.2 1.5h2.2L9.6 7l5.6 7.5h-4.4L7.3 10l-4 4.5H1.1L6.2 8.6.8 1.5h4.5l3.1 4.2 3.8-4.2Zm-.8 11.7h1.2L4.7 2.7H3.4l8 10.5Z"/></svg>"#,
    "linkedin": #"<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="currentColor" d="M3.6 5.6H1V15h2.6V5.6ZM2.3 1.2a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3ZM15 9.8c0-2.5-.6-4.4-3.5-4.4-1.4 0-2.3.8-2.7 1.5V5.6H6.3V15h2.6v-4.6c0-1.2.2-2.4 1.8-2.4 1.5 0 1.5 1.4 1.5 2.5V15H15V9.8Z"/></svg>"#,
    "web": #"<svg viewBox="0 0 16 16" aria-hidden="true"><path fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" d="M6.5 9.5l3-3M7 4.5l1-1a2.8 2.8 0 0 1 4 4l-1 1M9 11.5l-1 1a2.8 2.8 0 0 1-4-4l1-1"/></svg>"#,
]

/// The small round face (profile, sessions): same file name as the photo, made by scripts/caras.swift.
func face(of p: Person) -> String {
    "assets/caras/" + (p.photo.split(separator: "/").last.map(String.init) ?? p.photo)
}

func photo(_ p: Person) -> String {
    #"<img class="foto" src="\#(esc(p.photo))" alt="\#(esc(p.name))" width="800" height="1000" loading="lazy">"#
}

func info(_ p: Person, quote: Bool = false) -> String {
    let networks = [("x", p.x, "X"), ("linkedin", p.linkedin, "LinkedIn"), ("web", p.web, "su web")].compactMap { key, url, network in
        url.map { #"<a href="\#(esc($0))" target="_blank" rel="noopener me" aria-label="\#(esc(p.name)) en \#(network)">\#(icons[key]!)</a>"# }
    }.joined()
    let role = p.role.components(separatedBy: " · ").map { #"<span>\#(esc($0))</span>"# }.joined()
    // Ambassadors show their quote on the card front (the role stays for the profile); a blank one shows nothing.
    let shownQuote = p.quote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let line = quote && !shownQuote.isEmpty ? #"<p class="quote">\#(esc(shownQuote))</p>"# : ""
    return #"<div class="info"><div><h3>\#(esc(p.cardName))</h3><p class="role">\#(role)</p>\#(line)</div><p class="socials">\#(networks)</p></div>"#
}

/// The colour “h” stamped on every card.
let seal = #"<span class="card-seal" aria-hidden="true"><img src="assets/img/icono-h.svg" alt="" width="40" height="40" loading="lazy"></span>"#

/// The collectible card shared by founders and ambassadors.
///
/// The whole card is a button that opens the profile; it carries the bio and links the profile reads but doesn't show them.
/// - Parameter group: The series label on the back of the profile.
func card(_ p: Person, id: String, group: String, quote: Bool = false) -> String {
    #"""
    <article class="person reveal" data-since="\#(p.year)" data-group="\#(group)" data-name="\#(esc(p.name))" data-face="\#(esc(face(of: p)))">
      <div class="portrait">\#(photo(p))\#(seal)\#(info(p, quote: quote))</div>
      <div class="bio" id="\#(id)"><p>\#(esc(p.bio))</p></div>
      <button class="open-card" type="button" aria-haspopup="dialog" aria-label="Ver la ficha de \#(esc(p.name))"></button>
    </article>
    """#
}

func founder(_ p: Person, _ i: Int) -> String { card(p, id: "bio-founder-\(i)", group: "Founders") }
func ambassador(_ p: Person, _ i: Int) -> String { card(p, id: "bio-\(i)", group: "Embajadores", quote: true) }

/// data/meetups.json as is, in the `#meetups-data` script the page reads to re-render the sessions. `</` is escaped so
/// the JSON can't close the script tag.
func meetupsData() throws -> String {
    let json = try String(contentsOf: root.appending(path: "data/meetups.json"), encoding: .utf8)
    return "<script type=\"application/json\" id=\"meetups-data\">\n"
        + json.trimmingCharacters(in: .whitespacesAndNewlines).replacing("</", with: "<\\/") + "\n</script>"
}

/// The sponsors as die-cut stickers among ours, then the “Tu marca aquí” outline for the next one.
///
/// There is room for ``maxSponsors`` (CSS places each sticker by its order), so ``validate(_:errors:)`` rejects more.
func stickers(_ sponsors: [Sponsor]) -> String {
    let logos = sponsors.map { m in
        let img = #"<img src="\#(esc(m.logo))" alt="\#(esc(m.name))" loading="lazy">"#
        return m.web.map { #"<a class="sponsor-sticker" href="\#(esc($0))" target="_blank" rel="noopener sponsored">\#(img)</a>"# }
            ?? #"<span class="sponsor-sticker">\#(img)</span>"#
    }
    return (logos + [#"<span class="sponsor-slot" aria-hidden="true">Tu marca aquí</span>"#]).joined()
}

// MARK: - Calendar subscription

let calendarFile = root.appending(path: "sesiones.ics")

func calendarTime(_ d: Date) -> String {
    d.formatted(Date.VerbatimFormatStyle(format: "\(year: .defaultDigits)\(month: .twoDigits)\(day: .twoDigits)T\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))\(minute: .twoDigits)\(second: .twoDigits)Z", timeZone: .gmt, calendar: Calendar(identifier: .gregorian)))
}

func calendarEscaped(_ t: String) -> String {
    t.replacing("\\", with: "\\\\").replacing(",", with: "\\,").replacing(";", with: "\\;").replacing("\n", with: "\\n")
}

/// Splits a line into 75-byte pieces without cutting a UTF-8 character; iCalendar readers join them back.
func folded(_ line: String) -> String {
    var pieces: [String] = [], piece = "", limit = 75
    for c in line {
        if piece.utf8.count + c.utf8.count > limit { pieces.append(piece); piece = ""; limit = 74 }
        piece.append(c)
    }
    return (pieces + [piece]).joined(separator: "\r\n ")
}

func calendarDescription(_ q: Meetup) -> String {
    q.talks.compactMap { c -> String? in
        let names = (c.speakers ?? []).isEmpty ? nil : speakers(c)
        guard names != nil || c.title != nil else { return nil }
        return [names, c.title ?? "Próximamente"].compactMap { $0 }.joined(separator: ": ")
    }.joined(separator: "\n")
}

/// DTSTAMP is the session's start rather than the time of generating, so regenerating without changes gives the same file.
func sessionsCalendar(_ meetups: [Meetup], _ moments: [Moment]) -> String {
    let events = zip(meetups, moments).sorted { $0.1.ms < $1.1.ms }.flatMap { q, m -> [String] in
        let start = date(q.date)!
        return [
            "BEGIN:VEVENT", "UID:sesion-" + sessionId(m) + "@holaswift.com", "DTSTAMP:" + calendarTime(start),
            "DTSTART:" + calendarTime(start), "DTEND:" + calendarTime(start.addingTimeInterval(Double(durationMinutes(q)) * 60)),
            "SUMMARY:" + calendarEscaped("hola Swift: " + (q.title ?? sessionName(m) + " \(m.year)")), "DESCRIPTION:" + calendarEscaped(calendarDescription(q)),
            "LOCATION:Discord", "URL:https://holaswift.com/#sesiones", "END:VEVENT",
        ]
    }
    let lines = [
        "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//hola Swift//Sesiones//ES", "CALSCALE:GREGORIAN", "METHOD:PUBLISH",
        "X-WR-CALNAME:hola Swift", "X-WR-CALDESC:Las sesiones online de hola Swift", "X-WR-TIMEZONE:Europe/Madrid",
        "REFRESH-INTERVAL;VALUE=DURATION:PT6H", "X-PUBLISHED-TTL:PT6H",
    ] + events + ["END:VCALENDAR"]
    return lines.map(folded).joined(separator: "\r\n") + "\r\n"
}

// MARK: - Markers

/// Replaces what sits between a pair of `generated:NAME` markers, indented like the opening one.
///
/// Throws unless the opening marker appears exactly once and is followed by its closing marker.
func fill(_ html: String, _ name: String, _ content: String) throws -> String {
    let openMark = "<!-- generated:\(name) ", closeMark = "<!-- /generated:\(name) -->"
    let openings = html.ranges(of: openMark)
    guard openings.count == 1, let start = openings.first,
          let openMarkEnd = html[start.upperBound...].firstRange(of: "-->\n"),
          let end = html[openMarkEnd.upperBound...].firstRange(of: closeMark) else {
        throw Failure.markCount(name, html.ranges(of: openMark).count)
    }
    let line = html[..<start.lowerBound].lastIndex(of: "\n").map(html.index(after:)) ?? html.startIndex
    let indent = String(html[line..<start.lowerBound])
    let body = content.split(separator: "\n", omittingEmptySubsequences: false)
        .map { $0.isEmpty ? "\n" : indent + $0 + "\n" }.joined()
    return String(html[..<openMarkEnd.upperBound]) + body + indent + String(html[end.lowerBound...])
}

/// The page without the session rows, for `--check`.
///
/// The rows depend on when they were generated (which show, the countdown, “Ya pasó”) and the page re-renders them on
/// load, so only `#meetups-data` has to be up to date.
func withoutState(_ html: String) -> String {
    html.replacing(try! Regex(#"<!-- generated:sessions .*?<!-- /generated:sessions -->"#).dotMatchesNewlines(), with: "")
}

// MARK: - Program

let checkOnly = CommandLine.arguments.contains("--check")
var errors: [String] = []
let founders: [Person] = read("founders.json", fields: personFields, errors: &errors)
let ambassadors: [Person] = read("ambassadors.json", fields: personFields, errors: &errors)
let meetups: [Meetup] = read("meetups.json", fields: meetupFields, talks: talkFields, errors: &errors)
let sponsors: [Sponsor] = read("sponsors.json", fields: sponsorFields, errors: &errors)
validate(founders, "founders.json", errors: &errors)
validate(ambassadors, "ambassadors.json", errors: &errors)
validate(meetups, errors: &errors)
validate(sponsors, errors: &errors)
if !errors.isEmpty {
    print(errors.joined(separator: "\n"))
    exit(1)
}

do {
    let current = try String(contentsOf: page, encoding: .utf8)
    let moments = meetups.map { moment(date($0.date)!) }
    var updated = try fill(current, "founders", founders.enumerated().map { founder($1, $0) }.joined(separator: "\n"))
    updated = try fill(updated, "ambassadors", ambassadors.enumerated().map { ambassador($1, $0) }.joined(separator: "\n"))
    updated = try fill(updated, "sessions", sessionRows(meetups, moments: moments, today: moment(.now), clockOn: false))
    updated = try fill(updated, "meetups-data", meetupsData())
    updated = try fill(updated, "sponsors", stickers(sponsors))
    let calendar = sessionsCalendar(meetups, moments)
    let currentCalendar = try? String(contentsOf: calendarFile, encoding: .utf8)

    if checkOnly {
        guard withoutState(updated) == withoutState(current) else {
            print("index.html no está al día con data/*.json: pasa swift run generate")
            exit(1)
        }
        guard calendar == currentCalendar else {
            print("sesiones.ics no está al día con data/meetups.json: pasa swift run generate")
            exit(1)
        }
        print("data/ correcto, e index.html y sesiones.ics al día")
    } else {
        if updated == current {
            print("index.html ya estaba al día")
        } else {
            try updated.write(to: page, atomically: true, encoding: .utf8)
            print("index.html actualizado")
        }
        if calendar == currentCalendar {
            print("sesiones.ics ya estaba al día")
        } else {
            try calendar.write(to: calendarFile, atomically: true, encoding: .utf8)
            print("sesiones.ics actualizado")
        }
    }
} catch {
    print(error)
    exit(1)
}
