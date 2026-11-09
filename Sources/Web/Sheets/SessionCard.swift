import HolaSwift
import JavaScriptKit

/// The session card: like an ambassador's profile, the ticket flies from its row to the centre and flips to show every
/// talk in full, the sign-up form and the calendar link.
func setUpSessionCard() {
    guard let sheet = Sheet("session", closeMs: 950) else { return }
    sheets.append(sheet)
    let card = find(".session-card", inside: sheet.layer), front = find(".session-front", inside: card), back = find(".session-back", inside: card)
    let list = find("#sessions-list")
    let close = find(".close", inside: back)
    let signup = PillSignup(find(".sb-actions", inside: back), origin: "sesion")
    var origin: JSValue = .undefined
    // while the form is open or after signing up, the card's ✕ goes back to the button
    signup.changed = {
        _ = close.setAttribute("aria-label", signup.isOpen ? "Volver sin apuntarme" : signup.isDone ? "Volver" : "Cerrar")
    }

    func placeOver(_ row: JSValue) {
        // Scaled to the row's width with the tops lined up, not the centres: on a phone the open card is taller than the
        // row, and the ticket sits at the top of its front.
        let r = Box(row), w = decimal(card.offsetWidth), h = decimal(card.offsetHeight)
        guard r.width > 0, w > 0 else { _ = card.style.removeProperty("--from"); return }
        let k = r.width / w
        let dx = r.left + r.width / 2 - decimal(global.innerWidth) / 2, dy = r.top - viewportHeight() / 2 + k * h / 2
        _ = card.style.setProperty("--from", "translate(" + jsNumber(dx) + "px," + jsNumber(dy) + "px) scale(" + jsNumber(k) + ")")
    }
    // Each close queues its own card, to show again in its slot once the flight back lands. If that same card was reopened
    // meanwhile, it stays hidden (it's flying). All the timeouts last the same, so they land in order.
    var landing: [JSValue] = []
    let restore = closure { _ in
        guard !landing.isEmpty else { return }
        let card = landing.removeFirst()
        if sheet.isOpen && (sheet.layer.classList.contains("open").boolean ?? false) && isSame(card, origin) { return }
        _ = card.classList.remove("away")
    }
    sheet.onClose = {
        if origin.object != nil { placeOver(origin); landing.append(origin) }
        _ = global.setTimeout(restore, isStatic ? 0 : 950)
    }

    func open(_ row: JSValue) {
        guard let i = intValue(row.dataset.session), meetups.indices.contains(i) else { return }
        let q = meetups[i], m = moments[i], isPastSession = isPast(m, today: today)
        settleReveal(row)
        front.innerHTML = find(".ticket", inside: row).outerHTML
        for img in jsArray(front.querySelectorAll("img")) { img.loading = "eager" }
        _ = card.classList.toggle("next", row.classList.contains("next").boolean ?? false)
        _ = card.classList.toggle("past", isPastSession)
        _ = card.classList.toggle("compact", row.classList.contains("compact").boolean ?? false)
        find(".sb-kicker", inside: back).innerHTML = .string(sessionKicker(m))
        find("h3", inside: back).innerHTML = .string(q.title.map(esc) ?? spoiler([48, 28], soon: true))
        find(".sb-when", inside: back).textContent = .string(sessionLongDate(m))
        let notes = find(".sb-notes", inside: back)
        let shownNotes = q.notes ?? (q.title == nil ? sessionPendingNote(m) : nil)
        notes.textContent = .string(shownNotes ?? ""); notes.hidden = .boolean(shownNotes == nil)
        find(".sb-talks", inside: back).innerHTML = .string(sessionBackTalks(q))
        signup.origin = "sesion-" + sessionId(m)
        signup.reset()
        find(".sb-inner", inside: back).scrollTop = .number(0)
        origin = row
        sheet.show(focusElement: close, wait: true)
        // Place it over the row without a transition and force a layout, or the first time the browser paints it at full
        // size and there's no flight.
        card.style.transition = "none"
        placeOver(row)
        _ = card.offsetWidth
        card.style.transition = ""
        _ = row.classList.add("away")
    }

    // Delegated to the list: the rows are re-rendered with the visitor's date.
    listen(list, "click") { e in
        let row = nearest(e.target, ".session")
        if row.object != nil, nearest(e.target, ".open-session").object != nil { open(row) }
    }
    listen(find(".session-backdrop", inside: sheet.layer), "click") { _ in sheet.close() }
    listen(close, "click") { _ in
        guard signup.isOpen || signup.isDone else { sheet.close(); return }
        signup.reset()
        focusIfPossible(signup.go, scroll: false)
    }
}
