// The hero: the “hola Swift!” logo builds itself as if in a vector editor, the hand waves, the logo tilts with the
// pointer, and with a mouse there's an editor lens (skeletons under the cursor, piece selection) and Patricia's cursor
// on the heart.
//
// Each frame writes only what changed (rounded to 4 decimals), so once the logo is built only the hand, the tilt and the
// lens touch the page.

import HolaSwift
import JavaScriptKit
#if canImport(WASILibc)
import WASILibc   // sin, cos, exp: each frame's maths happens here, without crossing into JavaScript
#endif

// MARK: - Curves

func clamp(_ x: Double, _ a: Double, _ b: Double) -> Double { min(b, max(a, x)) }
func progress(_ t: Double, _ r: Span) -> Double { clamp((t - r.a) / (r.b - r.a == 0 ? 1e-3 : r.b - r.a), 0, 1) }
func smooth(_ x: Double) -> Double { -(cos(Double.pi * x) - 1) / 2 }
func easeOut(_ x: Double) -> Double { let y = 1 - x; return 1 - y * y * y }
func spring(_ x: Double) -> Double { x <= 0 ? 0 : exp(-6.5 * x) * sin(15 * x) }
func springIn(_ x: Double) -> Double { x <= 0 ? 0 : 1 - exp(-6 * x) * cos(12 * x) }
func round4(_ x: Double) -> Double { (x * 10_000).rounded() / 10_000 }

func decimal2(_ x: Double) -> String {
    guard x.isFinite else { return "0.00" }
    let n = Int((x * 100).rounded()), a = n < 0 ? -n : n, c = a % 100
    return (n < 0 ? "-" : "") + "\(a / 100)." + (c < 10 ? "0" : "") + "\(c)"
}

// MARK: - Choreography

let phases = [
    Phases(k: "hola", stroke: Span(a: 0.55, b: 1.8), meshProgress: Span(a: 1.55, b: 2.45), color: Span(a: 2.6, b: 3.4), jump: nil),
    Phases(k: "swift", stroke: Span(a: 1.95, b: 3.15), meshProgress: Span(a: 3.0, b: 3.7), color: Span(a: 3.85, b: 4.55), jump: nil),
    Phases(k: "destello", stroke: Span(a: 2.45, b: 2.46), meshProgress: Span(a: 2.45, b: 2.5), color: Span(a: 3.35, b: 3.6), jump: 2.45),
    Phases(k: "bang", stroke: Span(a: 3.2, b: 3.5), meshProgress: Span(a: 3.95, b: 4.2), color: Span(a: 4.6, b: 4.85), jump: 3.2),
]
let guideDraw = Span(a: 0, b: 0.85), guideReturn = Span(a: 0.95, b: 1.55)
let handPop = 4.15, handWave = 4.5, ready = 5.0

/// The build plays faster than the plan (5 s becomes about 4.25 s); once the logo is ready, time runs normally and the
/// hand waves at its own pace. Video mode (`__hero.seek`) uses plan time as is.
let pace = 0.85
func planTime(_ t: Double) -> Double { t < ready * pace ? t / pace : ready + (t - ready * pace) }

// MARK: - Logo lens

/// The bounds of each logo piece in the SVG's coordinates (``canvasWidth`` wide), for the editor-style selection.
let logoBoxes = [
    Box2D(name: "hola", x: 276.67662401146924, y: 329.0400961898879, w: 2053, h: 776),
    Box2D(name: "destello", x: -41, y: 1450, w: 252, h: 490), Box2D(name: "Swift", x: 382, y: 1137, w: 2337, h: 1143),
    Box2D(name: "!", x: 2782, y: 1201, w: 173, h: 725), Box2D(name: "mano", x: 2236, y: 120, w: 459.90234375, h: 470),
]
let canvasWidth = 3005.0

// MARK: - Hero start-up

func setUpHero() {
    let hero = byId("hero"), stage = byId("stage")
    guard hero.object != nil, stage.object != nil else { return }
    let video = global.Boolean(global.VIDEO).boolean ?? false   // recording: the capture drives time via __hero, not the clock
    let reduceMotion = !video && isStatic
    let pieces = phases.compactMap(Piece.init)
    let guide = document.querySelector(".lead path"), hand = document.querySelector(".hand"), text = document.querySelector(".copy")
    if guide.object != nil { guide.style.strokeDasharray = "1 1"; _ = guide.setAttribute("pathLength", "1") }
    let guideOffset = Cached<Double> { d in guide.style.strokeDashoffset = .number(d) }
    let handTransform = Cached<String> { t in hand.style.transform = .string(t) }
    let grid = Cached<Double> { g in _ = hero.style.setProperty("--grid", jsNumber(g)) }
    var prepared = false

    func renderFrame(_ t: Double) {
        guideOffset.set(round4(t < guideReturn.a ? 1 - easeOut(progress(t, guideDraw)) : -smooth(progress(t, guideReturn))))
        for piece in pieces { piece.renderFrame(t) }
        let k = t - handWave, cycle = k < 0 ? -1 : k.truncatingRemainder(dividingBy: 5.5)
        let envelope = cycle >= 0 && cycle < 1.5 ? sin(Double.pi * cycle / 1.5) : 0
        handTransform.set("scale(" + jsNumber(round4(springIn(t - handPop))) + ") rotate(" + decimal2(-4 + 20 * envelope * sin(cycle * 13)) + "deg)")
        grid.set(round4(1 - clamp((t - 3.8) / 1.4, 0, 1) * 0.85))
        if t > ready && !prepared { prepared = true; _ = hero.classList.add("ready") }
        if video {
            let c = easeOut(clamp((t - ready) / 0.7, 0, 1))
            text.style.opacity = .number(c); text.style.transform = .string("translateY(" + jsNumber((1 - c) * 24) + "px)")
            text.style.filter = .string("blur(" + jsNumber((1 - c) * 6) + "px)")
        }
    }

    let lens = byId("lens-c"), selection = byId("sel")
    let frameRect = find(".box", inside: selection), handles = jsArray(selection.querySelectorAll(".h"))
    let labelBackground = find(".tag rect", inside: selection), labelText = find(".tag text", inside: selection)
    var lx = -9999.0, ly = -9999.0, lr = 0.0, gx = -9999.0, gy = -9999.0, gr = 0.0, chosen: Int? = nil
    let lensX = Cached<String> { v in _ = lens.setAttribute("cx", v) }, lensY = Cached<String> { v in _ = lens.setAttribute("cy", v) }
    let lensR = Cached<String> { v in _ = lens.setAttribute("r", v) }

    func pick(_ x: Double, _ y: Double) -> Int? {
        var best: Int? = nil
        for (i, b) in logoBoxes.enumerated() where x > b.x - 40 && x < b.x + b.w + 40 && y > b.y - 40 && y < b.y + b.h + 40 {
            if best == nil || b.w * b.h < logoBoxes[best!].w * logoBoxes[best!].h { best = i }
        }
        return best
    }
    func drawSelection(_ b: Box2D, _ k: Double) {
        let p = 10 * k, x = b.x - p, y = b.y - p, w = b.w + 2 * p, h = b.h + 2 * p, side = 8 * k
        _ = frameRect.setAttribute("x", x); _ = frameRect.setAttribute("y", y); _ = frameRect.setAttribute("width", w); _ = frameRect.setAttribute("height", h)
        let corners = [(x, y), (x + w / 2, y), (x + w, y), (x + w, y + h / 2), (x + w, y + h), (x + w / 2, y + h), (x, y + h), (x, y + h / 2)]
        for (i, (cx, cy)) in corners.enumerated() where i < handles.count {
            _ = handles[i].setAttribute("x", cx - side / 2); _ = handles[i].setAttribute("y", cy - side / 2)
            _ = handles[i].setAttribute("width", side); _ = handles[i].setAttribute("height", side)
        }
        labelText.textContent = .string(b.name); _ = labelText.setAttribute("font-size", 12 * k)
        let tw = decimal(labelText.getComputedTextLength()) + 16 * k, th = 20 * k
        _ = labelBackground.setAttribute("x", x - 0.75 * k); _ = labelBackground.setAttribute("y", y - th - 6 * k)
        _ = labelBackground.setAttribute("width", tw); _ = labelBackground.setAttribute("height", th)
        _ = labelBackground.setAttribute("rx", 6 * k)
        _ = labelText.setAttribute("x", x - 0.75 * k + 8 * k); _ = labelText.setAttribute("y", y - th / 2 - 6 * k)
    }
    listen(stage, "pointermove") { e in
        guard sameText(e.pointerType.string ?? "", "mouse"), hero.classList.contains("ready").boolean == true else { return }
        let r = Box(stage), k = canvasWidth / r.width
        gx = (decimal(e.clientX) - r.left) * k; gy = (decimal(e.clientY) - r.top) * k; gr = min(150, r.width * 0.17) * k
        if lx < -9000 { lx = gx; ly = gy }
        let b = pick(gx, gy)
        if b != chosen { chosen = b; if let b { drawSelection(logoBoxes[b], k) }; _ = selection.classList.toggle("on", b != nil) }
    }
    listen(stage, "pointerleave") { _ in gr = 0; chosen = nil; _ = selection.classList.remove("on") }

    // Tilt only while the pointer moves; when still it eases back and the transform is removed so the SVG renders sharp.
    var px = 0.0, py = 0.0, rx = 0.0, ry = 0.0, lastMove = -1e9
    let tilt = Cached<String> { t in stage.style.transform = .string(t) }
    listen(global, "pointermove") { e in
        px = decimal(e.clientX) / decimal(global.innerWidth) - 0.5; py = decimal(e.clientY) / viewportHeight() - 0.5
        lastMove = decimal(global.performance.now())
    }

    var time = 0.0, speed = 1.0, previous = decimal(global.performance.now())
    func loop(_ now: Double) {
        // Follow the real clock even when frames are slow (Safari can take ~115 ms each here): a 0.05 s cap made the
        // animation run at under half speed. The cap only avoids a jump when coming back from another tab.
        let dt = min(0.25, (now - previous) / 1000); previous = now
        lx += (gx - lx) * 0.22; ly += (gy - ly) * 0.22; lr += (gr - lr) * 0.14
        if lens.object != nil { lensX.set(decimal1(lx)); lensY.set(decimal1(ly)); lensR.set(decimal1(max(0, lr))) }
        guard !reduceMotion else { return }
        time += dt * speed; renderFrame(planTime(time))
        let isStatic = now - lastMove > 1200, tx = isStatic ? 0 : -py * 5, ty = isStatic ? 0 : px * 7
        rx += (tx - rx) * 0.06; ry += (ty - ry) * 0.06
        tilt.set(abs(rx) < 0.02 && abs(ry) < 0.02 ? "none" : "rotateX(" + decimal2(rx) + "deg) rotateY(" + decimal2(ry) + "deg)")
    }
    if reduceMotion { renderFrame(9); hand.style.transform = "none" }
    if !video {
        var nextFrame: JSValue = .undefined
        nextFrame = closure { timestamp in loop(decimal(timestamp)); _ = global.requestAnimationFrame(nextFrame) }
        _ = global.requestAnimationFrame(nextFrame)
    }
    global.__hero = jsObject([
        ("seek", closure { t in time = decimal(t); renderFrame(time) }),
        ("pause", closure { _ in speed = 0 }),
    ])
    if !reduceMotion && !video { renderFrame(0) }   // so the first visible frame is already frame 0
    _ = hero.classList.add("animated")   // CSS stops hiding the logo: Swift drives it from here
    setUpHeroLens(hero: hero, stage: stage)
}

// MARK: - Lens across the whole hero

/// With a mouse, the background glyphs' skeletons show under the cursor and any piece of the hero can be “selected”, as
/// in an editor. Easter egg: the heart carries a multiplayer cursor with its designer's name.
func setUpHeroLens(hero: JSValue, stage: JSValue) {
    let selection = byId("selection"), colab = byId("colab")
    guard selection.object != nil else { return }
    let names: [(String, String)] = [("arroba", "@"), ("pregunta", "?"), ("codigo", "</>"), ("corazon", "♥"), ("enye", "ñ"), ("llaves", "{ }")]
    func glyph(_ k: String) -> String {
        for (key, name) in names where sameText(key, k) { return name }
        return "undefined"
    }
    let floaters = jsArray(document.querySelectorAll(".floater")).map { f -> (body: JSValue, skeleton: JSValue, name: String) in
        let body = find(".glyph-body", inside: f)
        return (body, find(".esq", inside: f), "Glifo " + glyph(body.dataset.k.string ?? ""))
    }
    let headline = document.querySelector(".copy h1")
    func font(_ el: JSValue) -> String {
        let computedStyle = global.getComputedStyle(el)
        var family = ""
        for c in (computedStyle.fontFamily.string ?? "").unicodeScalars {
            if c == "," { break }
            if c != "\"" { family.unicodeScalars.append(c) }
        }
        return family + " " + "\(Int(decimal(global.parseFloat(computedStyle.fontSize)).rounded()))"
    }
    func hoverTargets() -> [(el: JSValue, name: String)] {
        floaters.map { ($0.body, $0.name) } + [(headline, "Titular · " + font(headline))]
    }
    let label = find("b", inside: selection), colabName = find("span", inside: colab)
    var mx = -9999.0, my = -9999.0, sx = -9999.0, sy = -9999.0, lr = 0.0, lrMeta = 0.0
    var picked: JSValue? = nil
    listen(hero, "pointermove") { e in
        guard sameText(e.pointerType.string ?? "", "mouse"), hero.classList.contains("ready").boolean == true else { return }
        mx = decimal(e.clientX); my = decimal(e.clientY)
        if sx < -9000 { sx = mx; sy = my }
        lrMeta = min(150, Box(stage).width * 0.17)
        var best: (el: JSValue, name: String, area: Double)? = nil
        if byId("sel").classList.contains("on").boolean != true {
            for o in hoverTargets() where o.el.object != nil {
                let r = Box(o.el)
                if mx > r.left - 8 && mx < r.right + 8 && my > r.top - 8 && my < r.bottom + 8 && (best == nil || r.width * r.height < best!.area) {
                    best = (o.el, o.name, r.width * r.height)
                }
            }
        }
        picked = best?.el
        _ = selection.classList.toggle("on", best != nil)
        if let best { label.textContent = .string(best.name) }
        let placeOver = overHeart(best?.el)
        colab.style.transform = .string("translate(" + jsNumber(mx - 2) + "px," + jsNumber(my - 1.5) + "px)")
        _ = colab.classList.toggle("left", mx + decimal(colabName.offsetWidth) + 40 > decimal(global.innerWidth))
        _ = colab.classList.toggle("on", placeOver); _ = hero.classList.toggle("colab-on", placeOver)
    }
    listen(hero, "pointerleave") { _ in
        lrMeta = 0; picked = nil
        _ = selection.classList.remove("on"); _ = colab.classList.remove("on"); _ = hero.classList.remove("colab-on")
    }
    let placed = floaters.map { f in (Cached<String> { v in _ = f.skeleton.style.setProperty("--lx", v) },
                                     Cached<String> { v in _ = f.skeleton.style.setProperty("--ly", v) },
                                     Cached<String> { v in _ = f.skeleton.style.setProperty("--lr", v) }) }
    let box = (Cached<String> { v in selection.style.left = .string(v) }, Cached<String> { v in selection.style.top = .string(v) },
                Cached<String> { v in selection.style.width = .string(v) }, Cached<String> { v in selection.style.height = .string(v) })
    everyFrame {
        sx += (mx - sx) * 0.22; sy += (my - sy) * 0.22; lr += (lrMeta - lr) * 0.14
        let radius = decimal1(max(0, lr)) + "px"
        if lr > 0.04 || lrMeta > 0 {
            for (i, f) in floaters.enumerated() where f.skeleton.object != nil {
                let r = Box(f.skeleton)
                placed[i].0.set(decimal1(sx - r.left) + "px"); placed[i].1.set(decimal1(sy - r.top) + "px"); placed[i].2.set(radius)
            }
        } else {
            for p in placed { p.2.set(radius) }
        }
        if let picked {
            let r = Box(picked), h = Box(hero), p = 6.0
            box.0.set(jsNumber(r.left - h.left - p) + "px"); box.1.set(jsNumber(r.top - h.top - p) + "px")
            box.2.set(jsNumber(r.width + 2 * p) + "px"); box.3.set(jsNumber(r.height + 2 * p) + "px")
        }
    }
}

func overHeart(_ el: JSValue?) -> Bool {
    guard let el else { return false }
    return sameText(el.dataset.k.string ?? "", "corazon")
}
