import HolaSwift
import JavaScriptKit

let privacyNote = #"Al apuntarte aceptas la <a href="/privacidad" target="_blank" rel="noopener">política de privacidad</a>."#

/// The button that turns into the email field and signs up in place (sessions, in person).
/// HTML: a `.ps` with `.ps-form`, `.ps-go`, `.ps-note` and `.ps-ok`.
final class PillSignup {
    let actions, form, go, email, note, done: JSValue
    var origin: String
    /// After it opens, closes or signs up, so the owner can relabel its own ✕.
    var changed: () -> Void = {}

    // the closures keep it alive for the page's lifetime
    init(_ actions: JSValue, origin: String) {
        self.actions = actions; self.origin = origin
        form = find(".ps-form", inside: actions); go = find(".ps-go", inside: actions)
        email = find("input[type=email]", inside: actions); note = find(".ps-note", inside: actions); done = find(".ps-ok", inside: actions)
        listen(email, "input") { _ in if self.isOpen { self.go.disabled = .boolean(value(self.email).isEmpty) } }
        listen(form, "submit") { e in _ = e.preventDefault(); self.submit() }
        for back in [find(".ps-cancel", inside: actions), find(".ps-back", inside: actions)] where back.object != nil {
            listen(back, "click") { _ in self.reset(); focusIfPossible(self.go, scroll: false) }
        }
    }

    var isOpen: Bool { actions.classList.contains("open").boolean ?? false }
    var isDone: Bool { !(done.hidden.boolean ?? true) }

    /// CSS can only animate between known widths, so both are measured here into `--w0` and `--w1`.
    func open() {
        let w0 = decimal(go.offsetWidth), w1 = decimal(find(".ps-go-ok span", inside: go).offsetWidth) + 44
        _ = actions.style.setProperty("--w0", jsNumber(w0) + "px")
        _ = actions.style.setProperty("--w1", jsNumber(w1) + "px")
        _ = actions.offsetWidth   // apply the closed widths first, or there's nothing to animate from
        _ = actions.classList.add("open")
        go.disabled = .boolean(value(email).isEmpty)
        focusIfPossible(email, scroll: true)
        changed()
    }
    func close() {
        _ = actions.classList.remove("open"); _ = form.reset(); go.disabled = .boolean(false)
        _ = note.classList.remove("err"); note.innerHTML = .string(privacyNote)
        changed()
    }
    /// Like `close()`, and also after signing up.
    func reset() { close(); form.hidden = .boolean(false); done.hidden = .boolean(true); changed() }

    func submit() {
        guard isOpen else { open(); return }   // the first press only opens the field
        let address = value(email)
        guard isEmail(address) else {
            _ = note.classList.add("err"); note.textContent = "Revisa el email: parece que le falta algo."; return
        }
        go.disabled = .boolean(true)
        subscribe(address, origin: origin, honeypot: honeypot(inside: form)) { succeeded in
            self.go.disabled = .boolean(false)
            guard succeeded else { _ = self.note.classList.add("err"); self.note.textContent = .string(offlineMessage); return }
            self.close(); self.form.hidden = .boolean(true); self.done.hidden = .boolean(false)
            focusIfPossible(find(".ps-back", inside: self.actions), scroll: false)
            self.changed()
        }
    }
}
