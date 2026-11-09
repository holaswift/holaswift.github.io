// The page's entry point, compiled to WebAssembly with Embedded Swift (./scripts/build-web.sh writes it to assets/swift/).
//
// Embedded Swift has no Codable, so data is read field by field from JavaScript objects. Numbers and dates are left to
// the browser's Number, Intl and Date, so the .wasm doesn't have to carry that code.

import HolaSwift
import JavaScriptKit

let global = JSValue.object(JSObject.global)
let document = global.document

func find(_ selector: String, inside root: JSValue = document) -> JSValue {
    root.querySelector(selector)
}

/// The number in a JavaScript value, or `nil` if it isn't a finite one (converting NaN to `Int` traps).
func intValue(_ v: JSValue) -> Int? {
    guard let n = global.Number(v).number, n.isFinite else { return nil }
    return Int(n)
}

func options(_ pairs: [(String, String)]) -> JSValue {
    let o = global.Object.object!.new()
    for (key, value) in pairs { o[key] = .string(value) }
    return .object(o)
}

// MARK: - Reading the page's data

func text(_ o: JSValue, _ key: String) -> String? { o.object?[key].string }

func jsArray(_ o: JSValue) -> [JSValue] {
    guard let n = o.length.number else { return [] }
    return (0..<Int(n)).map { o[$0] }
}

func meetup(_ o: JSValue) -> Meetup? {
    guard let date = text(o, "date") else { return nil }
    let talks = jsArray(o.talks).compactMap { c -> Talk? in
        guard c.object != nil else { return nil }
        let speakers = c.speakers.object == nil ? nil : jsArray(c.speakers).compactMap { p -> Speaker? in
            text(p, "name").map { Speaker(name: $0, photo: text(p, "photo")) }
        }
        return Talk(title: text(c, "title"), speakers: speakers, type: text(c, "type"), description: text(c, "description"), summary: text(c, "summary"))
    }
    return Meetup(date: date, title: text(o, "title"), notes: text(o, "notes"), link: text(o, "link"), demo: o.demo.boolean, openSlot: o.openSlot.boolean, talks: talks)
}

// MARK: - Dates, with the browser's Intl

let madridTimeZone = "Europe/Madrid"
let parts = global.Intl.DateTimeFormat.object!.new("en-US", options([
    ("timeZone", madridTimeZone), ("year", "numeric"), ("month", "numeric"), ("day", "numeric"),
    ("hour", "numeric"), ("minute", "numeric"), ("hourCycle", "h23"),
]))

func moment(_ ms: Double) -> Moment {
    var year = 0, month = 1, day = 1, hour = 0, minute = 0
    for part in jsArray(JSValue.object(parts).formatToParts(ms)) {
        guard let value = intValue(part.value) else { continue }
        let type = part.type.string ?? ""
        if sameText(type, "year") { year = value }
        else if sameText(type, "month") { month = value }
        else if sameText(type, "day") { day = value }
        else if sameText(type, "hour") { hour = value }
        else if sameText(type, "minute") { minute = value }
    }
    return Moment(ms: ms, year: year, month: month, day: day, hour: hour, minute: minute)
}

func now() -> Double { global.Date.now().number ?? 0 }
func instant(_ date: String) -> Double { global.Date.parse(date).number ?? 0 }

// MARK: - Sessions

/// The sessions from the page's `#meetups-data` JSON, or `nil` if any can't be read, in which case the generated HTML
/// is left untouched.
let loaded: [Meetup]? = {
    guard let json = find("#meetups-data").textContent.string else { return nil }
    let info = global.JSON.parse(json)
    guard global.Array.isArray(info).boolean == true else { return nil }
    let meetups = jsArray(info).compactMap(meetup)
    return meetups.count == jsArray(info).count ? meetups : nil
}()
let meetups = loaded ?? []
let moments = meetups.map { moment(instant($0.date)) }
let today = moment(now())

func renderSessions() {
    let rows = find("#sessions-list")
    guard rows.object != nil else { return }
    rows.innerHTML = .string(sessionRows(meetups, moments: moments, today: today))
    appears(rows)
    startCountdown()
}

/// Ticks every countdown on the page (the row's and the copy on the open card) once a second.
///
/// The first tick runs immediately; otherwise, for a second, the clock would show what was drawn before it started.
func startCountdown() {
    func tick() {
        let t = now()
        for el in jsArray(document.querySelectorAll(".countdown[data-at]")) {
            guard let at = global.Number(el.dataset.at).number, at.isFinite else { continue }
            let minutes = intValue(el.dataset.minutes) ?? 60
            // Only rewrite on change: otherwise the “En directo” dot would restart its CSS animation every second.
            let shown = countdown(from: t, to: at, minutes: minutes)
            guard !sameText(el.dataset.shown.string ?? "", shown) else { continue }
            el.innerHTML = .string(shown); el.dataset.shown = .string(shown)
        }
    }
    tick()
    _ = global.setInterval(closure { _ in tick() }, 1000)
}


// MARK: - Ambassadors

/// A different order on every visit, so nobody is always first. The “Muy pronto” slot stays at the end.
func shuffleAmbassadors() {
    let container = find(".ambassadors-grid")
    guard container.object != nil else { return }
    var people = jsArray(container.querySelectorAll(":scope > article.person"))
    if people.count > 1 {
        for i in stride(from: people.count - 1, to: 0, by: -1) {
            people.swapAt(i, Int((global.Math.random().number ?? 0) * Double(i + 1)))
        }
    }
    for person in people.reversed() { _ = container.prepend(person) }
}

// MARK: - Start-up

setUpHero()

/// Sets up everything but the hero, two frames after it starts, so it doesn't steal time from the logo animation.
func setUpTheRest() {
    setUpPage()
    shuffleAmbassadors()
    if loaded != nil { renderSessions() }
    setUpSheets()
    setUpSessionCard()
    setUpDuo()
    setUpAR()
    document.documentElement.dataset.swift = "listo"   // index.html's CSS falls back to timed reveals without data-swift
    _ = global.console.log("hola 👋 Esta web corre en Swift compilado a WebAssembly.")
}
let later = closure { _ in setUpTheRest() }
_ = global.requestAnimationFrame(closure { _ in _ = global.requestAnimationFrame(closure { _ in _ = global.setTimeout(later, 0) }) })
