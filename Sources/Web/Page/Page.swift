// Animations live in CSS; Swift only decides when (classes) and where (transforms, CSS variables).
// Per-frame loops touch the page only when something changes, to cross into JavaScript as little as possible.

import HolaSwift
import JavaScriptKit

func jsNumber(_ x: Double) -> String { global.String(x).string ?? "0" }

func decimal1(_ x: Double) -> String {
    guard x.isFinite else { return "0.0" }
    let n = Int((x * 10).rounded()), a = n < 0 ? -n : n
    return (n < 0 ? "-" : "") + "\(a / 10).\(a % 10)"
}

func decimal(_ v: JSValue) -> Double {
    guard let n = global.Number(v).number, n.isFinite else { return 0 }
    return n
}

func clamp01(_ x: Double) -> Double { x.isFinite ? min(1, max(0, x)) : 0 }

func viewportHeight() -> Double { decimal(global.innerHeight) }

func everyFrame(_ body: @escaping () -> Void) {
    var nextFrame: JSValue = .undefined
    nextFrame = closure { _ in
        body()
        _ = global.requestAnimationFrame(nextFrame)
    }
    _ = global.requestAnimationFrame(nextFrame)
}

/// Whether the page is served over http(s); opened as a file, `history.replaceState` throws.
let hasServer: Bool = {
    let scheme = global.location.`protocol`.string ?? ""
    return sameText(scheme, "http:") || sameText(scheme, "https:")
}()

func replaceURL(_ url: String) {
    if hasServer { _ = global.history.replaceState(JSValue.null, "", url) }
}

// MARK: - Reveals

var revealObserver: JSValue = .undefined
let delays = ["0s", "0.08s", "0.16s"]

func appears(_ root: JSValue) {
    for (i, el) in jsArray(root.querySelectorAll(".reveal:not(.in)")).enumerated() {
        el.style.transitionDelay = .string(nearest(el, ".agenda,.people").object != nil ? delays[i % 3] : "0s")
        _ = revealObserver.observe(el)
    }
}

func setUpReveals() {
    revealObserver = .object(global.IntersectionObserver.object!.new(closure { entries in
        for e in jsArray(entries) where e.isIntersecting.boolean == true {
            let el = e.target
            _ = el.classList.add("in")
            _ = revealObserver.unobserve(el)
            // The stagger is only for appearing; left in place, it would delay every later transition too (such as the
            // cards' hover tilt, which would never catch up with the mouse).
            _ = global.setTimeout(closure { _ in _ = el.style.removeProperty("transition-delay") }, 1300)
        }
    }, jsObject([("threshold", .number(0.2))])))
    appears(document)
}

// MARK: - Top bar

func setUpNavBar() {
    let bar = byId("top"), headline = document.querySelector(".copy h1"), theme = byId("theme")
    let darkSections = [byId("manifiesto"), byId("presencial")].filter { $0.object != nil }
    let observer = global.IntersectionObserver.object!.new(closure { entries in
        _ = bar.classList.toggle("solid", !(entries[0].isIntersecting.boolean ?? false))
    }, jsObject([("rootMargin", .string("-80px 0px 0px 0px"))]))
    if headline.object != nil { _ = JSValue.object(observer).observe(headline) }
    guard !darkSections.isEmpty else { return }
    var dark: Bool? = nil
    func watch() {
        let half = Box(bar).bottom * 0.5
        let now = darkSections.contains { let r = Box($0); return r.top < half && r.bottom > half }
        guard now != dark else { return }
        dark = now
        _ = bar.classList.toggle("dark", now)
        if theme.object != nil { theme.content = .string(now ? "#0C0B0B" : "#F7F7F7") }
        document.documentElement.style.backgroundColor = .string(now ? "#0C0B0B" : "")
    }
    listen(global, "scroll", passive: true) { _ in watch() }
    listen(global, "resize") { _ in watch() }
    watch()
}

// MARK: - Manifesto and background

/// Screens without scroll animations: “Reduce motion”, or short landscape ones, where the manifesto isn't pinned.
let staticScreen = global.matchMedia("(prefers-reduced-motion: reduce), (max-height:520px) and (orientation:landscape)").matches.boolean ?? false

func setUpManifesto() {
    let section = byId("manifiesto"), text = byId("manifesto-text"), group = byId("glyph-group")
    guard section.object != nil, text.object != nil else { return }
    // --i: the CSS lights the words one after another
    var index = 0
    for node in jsArray(text.querySelectorAll(".txt")) {
        let words = splitText(node.textContent.string ?? "", by: " ")
        node.innerHTML = .string(words.map { word in
            defer { index += 1 }
            return #"<span class="w" style="--i:\#(index)">"# + esc(word) + "</span>"
        }.joined(separator: " "))
    }
    if staticScreen {
        _ = section.classList.add("static")
        _ = group.classList.add("together", "opened")
        return
    }
    // from the section's top coming up the screen: it opens on arrival, not after a scroll of nothing
    var together = false, opened = false
    everyFrame {
        let top = Box(section).top, h = viewportHeight()
        if (top < h * 0.5) != together { together = top < h * 0.5; _ = group.classList.toggle("together", together) }
        if (top < h * 0.12) != opened { opened = top < h * 0.12; _ = group.classList.toggle("opened", opened) }
    }
}

/// Splits like JavaScript's `split()`, keeping the empty chunks between consecutive separators.
func splitText(_ t: String, by separator: Unicode.Scalar) -> [String] {
    var chunks: [String] = [], current = ""
    for c in t.unicodeScalars {
        if c == separator { chunks.append(current); current = "" } else { current.unicodeScalars.append(c) }
    }
    chunks.append(current)
    return chunks
}

func setUpParallax() {
    let floaters = jsArray(document.querySelectorAll(".floater"))
    guard !floaters.isEmpty else { return }
    let depth = floaters.map { decimal($0.dataset.d) }
    var fx = 0.0, fy = 0.0, cx = 0.0, cy = 0.0
    var placed = Array(repeating: ("", ""), count: floaters.count)
    listen(global, "pointermove") { e in
        guard sameText(e.pointerType.string ?? "", "mouse") else { return }
        fx = decimal(e.clientX) / decimal(global.innerWidth) - 0.5
        fy = decimal(e.clientY) / viewportHeight() - 0.5
    }
    everyFrame {
        cx += (fx - cx) * 0.06; cy += (fy - cy) * 0.06
        guard !staticScreen else { return }
        for i in floaters.indices {
            let px = decimal1(-cx * depth[i]) + "px", py = decimal1(-cy * depth[i]) + "px"
            if !sameText(px, placed[i].0) { _ = floaters[i].style.setProperty("--px", px) }
            if !sameText(py, placed[i].1) { _ = floaters[i].style.setProperty("--py", py) }
            placed[i] = (px, py)
        }
    }
}

// MARK: - The letter

/// The manifesto letter: the envelope flies to the centre and opens, and the letter grows until it can be read.
///
/// Esc or ✕ close it, folding it back into the envelope; `#carta` in the URL opens it directly.
func setUpLetter() {
    let layer = byId("carta")
    guard layer.object != nil else { return }
    let reading = find(".reading", inside: layer), closeButton = find(".close-letter", inside: layer), signatures = byId("signatures")
    let flight = find(".flight", inside: layer), letter = find(".letter", inside: layer), paper = find(".envelope-paper", inside: flight)
    let envelope = document.querySelector(".glyph-group .envelope"), group = byId("glyph-group")
    let sheet = document.querySelector(".glyph-group .envelope-paper")   // the manifesto's letter, out of its open envelope
    var pending: [JSValue] = [], returnTo: JSValue = .undefined, fromSheet = false

    func rest() -> [JSValue] {
        jsArray(document.body.children).filter { !isSame($0, layer) && !sameText($0.tagName.string ?? "", "SCRIPT") }
    }
    func translate(_ dx: Double, _ dy: Double, scale: Double) -> String {
        "translate(" + jsNumber(dx) + "px," + jsNumber(dy) + "px) scale(" + jsNumber(scale) + ")"
    }
    func step(_ ms: Int, _ body: @escaping () -> Void) -> () -> Void {
        let c = closure { _ in body() }
        return { pending.append(global.setTimeout(c, ms)) }
    }

    /// The letter's origin is its top centre; with `height` it's squashed to that height too.
    func fit(_ c: Box, to p: Box, height: Double? = nil) -> String {
        let kx = p.width / c.width, ky = height.map { $0 / c.height } ?? kx
        return "translate(" + jsNumber(p.left - c.left - (c.width * (1 - kx)) / 2) + "px," + jsNumber(p.top - c.top) + "px) scale("
            + jsNumber(kx) + "," + jsNumber(ky) + ")"
    }
    func growLetter(from p: Box, height: Double? = nil) {
        _ = layer.classList.add("read")
        _ = letter.classList.add("from")
        letter.style.transform = .string(fit(Box(letter), to: p, height: height))
        _ = letter.offsetWidth   // force a layout so the transition starts from here
        _ = letter.classList.add("grow"); _ = letter.classList.remove("from"); letter.style.transform = ""
    }
    /// The part of the sheet that's out: the letter grows from it, not from the foot inside the envelope.
    func sheetOut() -> Double { max(0, Box(envelope).top - Box(sheet).top) }
    /// Watched only once the letter is full size: while it grows, squashed, its foot is on screen and they'd be drawn unseen.
    let signaturesSeen = global.IntersectionObserver.object!.new(closure { entries in
        for e in jsArray(entries) where e.isIntersecting.boolean == true { _ = signatures.classList.add("in") }
    }, jsObject([("root", reading), ("threshold", .number(0.6))]))
    func signed() { _ = JSValue.object(signaturesSeen).observe(signatures) }
    func onScreen(_ b: Box) -> Bool { b.width > 0 && b.bottom > 0 && b.top < viewportHeight() }

    let opening = closure { _ in _ = layer.classList.add("open") }
    let steps = [
        step(700) { _ = layer.classList.add("seal") },
        step(900) { _ = layer.classList.add("flap") },
        step(1350) { _ = layer.classList.add("out") },
        step(2000) { growLetter(from: Box(paper)) },
        step(2800) { _ = letter.classList.remove("grow"); signed(); focusIfPossible(closeButton) },
    ]

    // the sheet comes further out first, on the page; then the letter grows from it
    let lifted = closure { _ in
        let s = Box(sheet)
        _ = layer.classList.add("seal", "flap", "out", "from-sheet"); _ = global.requestAnimationFrame(opening)
        growLetter(from: s, height: sheetOut())
        step(220) { sheet.style.visibility = "hidden" }()   // only once the letter, fading in over it, covers it
        step(800) { _ = letter.classList.remove("grow"); signed(); focusIfPossible(closeButton) }()
    }
    // no opening delays on the way back
    let landed = closure { _ in _ = group.classList.remove("landing") }

    func open(direct: Bool) {
        guard layer.hidden.boolean == true, !fromSheet else { return }
        returnTo = document.activeElement
        let fromManifesto = !direct && !isStatic && group.classList.contains("opened").boolean == true && onScreen(Box(sheet))
        layer.hidden = .boolean(false); document.documentElement.style.overflow = "hidden"
        for el in rest() { el.inert = .boolean(true) }
        replaceURL("#carta")
        if direct || isStatic {
            _ = layer.classList.add("open", "seal", "flap", "out", "read"); signed(); focusIfPossible(closeButton); return
        }
        if fromManifesto {
            fromSheet = true
            _ = group.classList.add("lifting")
            pending.append(global.setTimeout(lifted, 420))
            return
        }
        let r = Box(envelope)
        if r.width > 0 {
            let v = Box(flight)
            flight.style.transition = "none"; flight.style.opacity = "1"
            flight.style.transform = .string(translate(r.left + r.width / 2 - (v.left + v.width / 2), r.top + r.height / 2 - (v.top + v.height / 2), scale: r.width / v.width))
            envelope.style.visibility = "hidden"
            _ = flight.offsetWidth
            flight.style.transition = ""; flight.style.transform = ""; flight.style.opacity = ""
        }
        _ = global.requestAnimationFrame(opening)
        for p in steps { p() }
    }

    func finish() {
        layer.hidden = .boolean(true)
        _ = layer.classList.remove("read", "out", "flap", "seal", "open", "closing", "from-sheet")
        reading.scrollTop = .number(0); _ = signatures.classList.remove("in"); _ = JSValue.object(signaturesSeen).disconnect()
        _ = letter.classList.remove("grow", "from", "returning", "to-sheet"); letter.style.transform = ""
        if envelope.object != nil { envelope.style.visibility = "" }
        if sheet.object != nil { sheet.style.visibility = "" }
        if group.classList.contains("lifting").boolean == true {
            _ = group.classList.add("landing"); _ = group.classList.remove("lifting")
            _ = global.setTimeout(landed, 500)
        }
        fromSheet = false
    }
    let finishLater = closure { _ in finish() }
    let restoreFocus = closure { _ in focusIfPossible(returnTo) }

    func close() {
        guard layer.hidden.boolean == false, layer.classList.contains("closing").boolean != true else { return }
        for t in pending { _ = global.clearTimeout(t) }
        pending = []
        for el in rest() { el.inert = .boolean(false) }
        document.documentElement.style.overflow = ""
        replaceURL((global.location.pathname.string ?? "") + (global.location.search.string ?? ""))
        _ = global.setTimeout(restoreFocus, 0)
        if isStatic { finish(); return }
        let c = Box(letter), r = Box(envelope), s = Box(sheet)
        _ = layer.classList.add("closing")
        if fromSheet && onScreen(s) {
            // the sheet shows again under it just before it lands
            _ = letter.classList.add("returning", "to-sheet")
            letter.style.transform = .string(fit(c, to: s, height: sheetOut()))
            step(380) { sheet.style.visibility = "" }()
        } else if onScreen(r) {
            _ = letter.classList.add("returning")
            letter.style.transform = .string(translate(r.left + r.width / 2 - (c.left + c.width / 2), r.top + r.height * 0.2 - c.top, scale: r.width / c.width))
        }
        _ = global.setTimeout(finishLater, 520)
    }

    for button in jsArray(document.querySelectorAll("[data-open-letter]")) { listen(button, "click") { _ in open(direct: false) } }
    listen(closeButton, "click") { _ in close() }
    listen(reading, "click") { e in if isSame(e.target, reading) { close() } }
    listen(global, "keydown") { e in if sameText(e.key.string ?? "", "Escape") { close() } }
    if sameText(global.location.hash.string ?? "", "#carta") { open(direct: true) }
}

func setUpPage() {
    setUpReveals()
    setUpNavBar()
    setUpManifesto()
    setUpParallax()
    setUpLetter()
}
