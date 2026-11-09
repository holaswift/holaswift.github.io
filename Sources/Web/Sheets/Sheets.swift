// The page's sheets (ambassador profile, “Avísame”, sponsorship) and the sign-up forms. Their shared behaviour lives in
// Sheet; the session card has its own file, SessionCard.

import HolaSwift
import JavaScriptKit

// MARK: - The page's sheets

var sheets: [Sheet] = []

/// An ambassador's profile, as a trading card: it flies from the grid to the centre and flips to show the bio and links.
func setUpProfileCard() {
    guard let sheet = Sheet("profile", closeMs: 950) else { return }
    sheets.append(sheet)
    let tradingCard = find(".trading-card", inside: sheet.layer), front = find(".front", inside: tradingCard), back = find(".back", inside: tradingCard)
    let cards = jsArray(document.querySelectorAll(".card-grid .person"))
    var origin: JSValue = .undefined
    func placeOver(_ p: JSValue) {
        // The grid card may be tilted (`rotate`) and resized (`scale`); the flying card copies both, and its size comes from
        // the untransformed width because a tilted card's bounding box is bigger.
        let r = Box(p), w = decimal(tradingCard.offsetWidth), cardWidth = decimal(p.offsetWidth)
        guard cardWidth > 0, w > 0 else { _ = tradingCard.style.removeProperty("--from"); return }
        let style = global.getComputedStyle(p)
        let tilt = decimal(global.parseFloat(style.rotate)), size = decimal(global.parseFloat(style.scale))
        let dx = r.left + r.width / 2 - decimal(global.innerWidth) / 2, dy = r.top + r.height / 2 - viewportHeight() / 2
        _ = tradingCard.style.setProperty("--from", "translate(" + jsNumber(dx) + "px," + jsNumber(dy) + "px) rotate("
            + jsNumber(tilt.isFinite ? tilt : 0) + "deg) scale(" + jsNumber(cardWidth * (size.isFinite && size > 0 ? size : 1) / w) + ")")
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
    func open(_ p: JSValue) {
        let photo = find(".foto", inside: p), src: JSValue = photo.object != nil ? photo.src : .string("")
        let cardName = find("h3", inside: p).textContent, name = p.dataset.name.string.map { JSValue.string($0) } ?? cardName, role = find(".role", inside: p).innerHTML
        find(".foto", inside: front).src = src
        find(".name", inside: front).textContent = cardName; find(".role", inside: front).innerHTML = role
        let quote = find(".quote", inside: p), frontQuote = find(".quote", inside: front)
        frontQuote.textContent = quote.object != nil ? quote.textContent : .string("")
        frontQuote.className = .string(quote.object != nil ? (quote.className.string ?? "quote") : "quote")
        _ = tradingCard.classList.toggle("ambassador", sameText(p.dataset.group.string ?? "", "Embajadores"))
        _ = tradingCard.classList.toggle("founder", sameText(p.dataset.group.string ?? "", "Founders"))
        let face = find(".face", inside: back)
        face.src = p.dataset.face.string.map { JSValue.string($0) } ?? src; face.hidden = .boolean(photo.object == nil)
        find("h3", inside: back).textContent = name; find(".role", inside: back).innerHTML = role
        let bio = find(".bio", inside: p)
        find(".series-group", inside: back).textContent = .string(p.dataset.group.string ?? "Embajadores")
        let year = intValue(p.dataset.since) ?? Person.foundingYear
        find(".foot-series", inside: back).textContent = .string(year == Person.foundingYear ? "Serie fundacional" : "Serie")
        find(".foot-year", inside: back).textContent = .string("\(year)")
        find(".bio-text", inside: back).textContent = .string(bio.object != nil ? trimmed(bio.textContent.string ?? "") : "")
        find(".actions", inside: back).innerHTML = .string(jsArray(p.querySelectorAll(".socials a")).map { a in
            let network = afterLast(" en ", a.getAttribute("aria-label").string ?? "")
            let kind = sameText(network, "X") ? "x" : sameText(network, "LinkedIn") ? "linkedin" : "web"   // .link-* sets the colour in CSS
            return #"<a class="link-"# + kind + #"" href=""# + esc(a.href.string ?? "") + #"" target="_blank" rel="noopener me">"# + (a.innerHTML.string ?? "")
                + "<span>" + esc(sameText(network, "su web") ? "Web" : network) + "</span></a>"
        }.joined())
        origin = p
        settleReveal(p)
        sheet.show(focusElement: find(".close", inside: back), wait: true)
        // Place it over the card without a transition and force a layout, or the first time the browser paints it at full
        // size and there's no flight.
        tradingCard.style.transition = "none"
        placeOver(p)
        _ = tradingCard.offsetWidth
        tradingCard.style.transition = ""
        _ = p.classList.add("away")
    }
    func degrees(_ v: Double) -> String { jsNumber((v * 10).rounded() / 10) + "deg" }
    func unit(_ v: Double) -> Double { v.isFinite ? max(-1, min(1, v)) : 0 }
    for p in cards {
        let button = find(".open-card", inside: p)
        guard button.object != nil else { continue }
        listen(button, "click") { _ in open(p) }
        // Decode the flying card's photo before the click: decoding an 800 × 1000 photo would eat the start of the flight.
        let prepare: (JSValue) -> Void = { _ in
            guard !sheet.isOpen else { return }
            let photo = find(".foto", inside: p), flying = find(".foto", inside: front)
            guard photo.object != nil, flying.object != nil else { return }
            if !sameText(flying.src.string ?? "", photo.src.string ?? "") { flying.src = photo.src }
            warmUp(flying)
        }
        listen(p, "pointerenter", prepare); listen(p, "pointerdown", prepare); listen(button, "focus", prepare)
        // 3D tilt following the mouse, measured from the card's centre: it barely moves while tilting, so it doesn't
        // feed back on itself.
        listen(p, "pointermove") { e in
            guard sameText(e.pointerType.string ?? "", "mouse"), !isStatic else { return }
            let r = Box(p)
            guard r.width > 0, r.height > 0 else { return }
            let x = unit((decimal(e.clientX) - r.left - r.width / 2) / (r.width / 2))
            let y = unit((decimal(e.clientY) - r.top - r.height / 2) / (r.height / 2))
            _ = p.style.setProperty("--rx", degrees(-y * 9))
            _ = p.style.setProperty("--ry", degrees(x * 9))
            _ = p.style.setProperty("--px", jsNumber((x * 100).rounded() / 100))   // for the depth of the photo
            _ = p.style.setProperty("--py", jsNumber((y * 100).rounded() / 100))
        }
        listen(p, "pointerleave") { _ in
            _ = p.style.removeProperty("--rx"); _ = p.style.removeProperty("--ry")
            _ = p.style.removeProperty("--px"); _ = p.style.removeProperty("--py")
        }
    }
    listen(find(".profile-backdrop", inside: sheet.layer), "click") { _ in sheet.close() }
    listen(find(".close", inside: back), "click") { _ in sheet.close() }
}

func afterLast(_ separator: String, _ t: String) -> String {
    let scalars = Array(t.unicodeScalars), sep = Array(separator.unicodeScalars)
    guard scalars.count >= sep.count else { return t }
    var i = scalars.count - sep.count
    while i >= 0 {
        if Array(scalars[i..<(i + sep.count)]) == sep {
            var s = ""
            for c in scalars[(i + sep.count)...] { s.unicodeScalars.append(c) }
            return s
        }
        i -= 1
    }
    return t
}

/// Sets up a sheet with a form: opening, closing, validation and sending.
/// - Parameters:
///   - delegate: Listen for clicks on the whole document, for openers that may appear anywhere.
///   - send: Submits the form and calls its argument with `true` if it worked; without it, the form counts as sent.
///   - validateFields: Returns the error message and the id of the field to focus, or `nil` if the form is valid.
func setUpForm(_ id: String, openMark selector: String, delegate: Bool, firstField: String,
                        send: ((@escaping (Bool) -> Void) -> Void)? = nil, failureMessage: String = offlineMessage,
                        validateFields: @escaping () -> (message: String, field: String)?) {
    guard let sheet = Sheet(id, closeMs: 400) else { return }
    sheets.append(sheet)
    let form = byId(id + "-form"), thanks = find(".sponsor-ok", inside: sheet.layer), error = byId(id + "-error")
    func open(_ trigger: JSValue) {
        form.hidden = .boolean(false); thanks.hidden = .boolean(true); error.textContent = ""
        sheet.show(focusElement: byId(firstField), wait: true)
    }
    if delegate {
        listen(document, "click") { e in
            let trigger = nearest(e.target, selector)
            if trigger.object != nil { _ = e.preventDefault(); open(trigger) }
        }
    } else {
        for button in jsArray(document.querySelectorAll(selector)) { listen(button, "click") { _ in open(button) } }
    }
    for button in jsArray(sheet.layer.querySelectorAll(".close,[data-close-" + id + "]")) { listen(button, "click") { _ in sheet.close() } }
    sheet.closeOnOutsideClick(background: "sponsor-backdrop")
    listen(form, "submit") { e in
        _ = e.preventDefault()
        if let failure = validateFields() {
            error.textContent = .string(failure.message)
            focusIfPossible(byId(failure.field), scroll: true)
            return
        }
        error.textContent = ""
        func done() {
            form.hidden = .boolean(true); thanks.hidden = .boolean(false); _ = form.reset()
            focusIfPossible(find("button", inside: thanks))
        }
        guard let send = send else { done(); return }
        let button = find("[type=submit]", inside: form)
        button.disabled = .boolean(true)
        send { succeeded in
            button.disabled = .boolean(false)
            if succeeded { done() } else { error.textContent = .string(failureMessage) }
        }
    }
}

/// The “Avísame” sheet, opened from the bar. (The in-person section signs up in place, with a ``PillSignup``.)
func setUpNotifyMe() {
    setUpForm("notify", openMark: "[data-open-notify]", delegate: true, firstField: "notify-email",
                       send: { ready in subscribe(value(byId("notify-email")), origin: "avisame", honeypot: honeypot(inside: byId("notify-form")), ready: ready) }) {
        let email = value(byId("notify-email"))
        if !isEmail(email) { return (email.isEmpty ? "Escribe tu email para avisarte." : "Revisa el email: parece que le falta algo.", "notify-email") }
        if byId("notify-consent").checked.boolean != true { return ("Necesitamos que aceptes la política de privacidad.", "notify-consent") }
        return nil
    }
}

func setUpSponsorship() {
    setUpForm("sponsor", openMark: "[data-open-sponsor]", delegate: false, firstField: "sponsor-name",
                       send: { ready in
                           sendSponsorship(name: value(byId("sponsor-name")), company: value(byId("sponsor-company")),
                                            email: value(byId("sponsor-email")), message: value(byId("sponsor-message")),
                                            honeypot: honeypot(inside: byId("sponsor-form")), ready: ready)
                       },
                       failureMessage: "No hemos podido enviar tu mensaje. Inténtalo de nuevo o escríbenos a patrocinio@holaswift.com.") {
        if value(byId("sponsor-name")).isEmpty { return ("Dinos cómo te llamas.", "sponsor-name") }
        if !isEmail(value(byId("sponsor-email"))) { return ("Revisa el email: parece que le falta algo.", "sponsor-email") }
        if value(byId("sponsor-message")).isEmpty { return ("Cuéntanos un poco en el mensaje.", "sponsor-message") }
        if byId("sponsor-consent").checked.boolean != true { return ("Necesitamos que aceptes la política de privacidad.", "sponsor-consent") }
        return nil
    }
}

/// The form at the top of the page: validates and adds the email to the mailing list.
func setUpSignup() {
    let form = byId("signup"), note = byId("signup-note"), email = byId("email")
    listen(form, "submit") { e in
        _ = e.preventDefault()
        let text = value(email)
        if text.isEmpty {
            note.className = "signup-note err"; note.textContent = "Escribe tu email para que podamos avisarte."; focusIfPossible(email, scroll: true); return
        }
        if email.checkValidity().boolean != true || !isEmail(text) {
            note.className = "signup-note err"; note.textContent = "Ese email no parece correcto. Revisa que lleve @ y dominio."; focusIfPossible(email, scroll: true); return
        }
        let button = find("button", inside: form)
        button.disabled = .boolean(true); email.disabled = .boolean(true)
        subscribe(text, origin: "web", honeypot: honeypot(inside: form)) { succeeded in
            button.disabled = .boolean(false); email.disabled = .boolean(false)
            if succeeded {
                _ = form.reset()
                note.className = "signup-note ok"; note.textContent = "¡Casi! Revisa tu correo y confirma tu email."
            } else {
                note.className = "signup-note err"; note.textContent = .string(offlineMessage)
            }
        }
    }
}

func setUpSheets() {
    setUpSignup()
    setUpNotifyMe()
    let inPerson = document.querySelector(".ip-signup")
    if inPerson.object != nil { _ = PillSignup(inPerson, origin: "presencial") }
    setUpProfileCard()
    setUpSponsorship()
    listen(global, "keydown") { e in
        if sameText(e.key.string ?? "", "Escape") { for sheet in sheets { sheet.close() } }
    }
}
