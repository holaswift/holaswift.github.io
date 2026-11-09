import HolaSwift
import JavaScriptKit

/// Keeps every ``closure(_:)`` alive: the page may call it at any time, and a released `JSClosure` traps.
var alive: [JSClosure] = []

func closure(_ body: @escaping (JSValue) -> Void) -> JSValue {
    let c = JSClosure { args in
        body(args.first ?? .undefined)
        return .undefined
    }
    alive.append(c)
    return .object(c)
}

func listen(_ v: JSValue, _ event: String, passive: Bool = false, _ body: @escaping (JSValue) -> Void) {
    guard v.object != nil else { return }
    _ = v.addEventListener(event, closure(body), passive ? jsObject([("passive", .boolean(true))]) : .undefined)
}

func jsObject(_ pairs: [(String, JSValue)]) -> JSValue {
    let o = global.Object.object!.new()
    for (key, value) in pairs { o[key] = value }
    return .object(o)
}

func byId(_ id: String) -> JSValue { document.getElementById(id) }

func isSame(_ a: JSValue, _ b: JSValue) -> Bool { global.Object.is(a, b).boolean ?? false }

/// `closest()` that tolerates non-elements: an event target may not be one, and calling a missing method traps.
func nearest(_ v: JSValue, _ selector: String) -> JSValue {
    guard v.object?["closest"].function != nil else { return .null }
    return v.closest(selector)
}

let noScroll = jsObject([("preventScroll", .boolean(true))])

func focusIfPossible(_ v: JSValue, scroll: Bool = false) {
    guard v.object?["focus"].function != nil else { return }
    _ = scroll ? v.focus() : v.focus(noScroll)
}

func value(_ field: JSValue) -> String { trimmed(field.value.string ?? "") }

let isStatic = global.matchMedia("(prefers-reduced-motion: reduce)").matches.boolean ?? false

/// Finishes a scroll reveal at once, so a card about to fly is measured where it really is, not mid-transition.
func settleReveal(_ el: JSValue) {
    guard el.classList.contains("reveal").boolean == true else { return }
    el.style.transition = "none"
    _ = el.classList.add("in")
    _ = el.offsetWidth
    el.style.transition = ""
}

/// Gets an image ready to paint (downloaded and decoded) before it's needed, so a flight doesn't stall on its first frames.
func warmUp(_ img: JSValue) {
    guard img.object?["decode"].function != nil else { return }
    _ = img.decode().then(closure { _ in }, closure { _ in })   // a rejection only means it isn't ready yet
}
