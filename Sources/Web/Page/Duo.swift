// iPhone Duo: Safari leaves a strip of controls on the right and paints only real document content under it.
// To fill it, a column is hung from the body just past the window's edge and each section's background is rebuilt there
// (the hero's dot grid, the manifesto's rounded corner, the veil of any open sheet). On other devices this does nothing.

import HolaSwift
import JavaScriptKit

func includes(_ t: String, _ chunk: String) -> Bool {
    let a = Array(t.unicodeScalars), b = Array(chunk.unicodeScalars)
    guard !b.isEmpty, a.count >= b.count else { return b.isEmpty }
    for i in 0...(a.count - b.count) where Array(a[i..<(i + b.count)]) == b { return true }
    return false
}

func colorComponents(_ t: String) -> [Double] {
    var numbers: [Double] = [], current = ""
    func close() { if !current.isEmpty { numbers.append(decimal(.string(current))); current = "" } }
    for c in t.unicodeScalars {
        if (c >= "0" && c <= "9") || c == "." { current.unicodeScalars.append(c) } else { close() }
    }
    close()
    return numbers
}

func px(_ x: Double) -> String { jsNumber(x) + "px" }

let openLayerSelector = ".letter-layer.open, .sponsor-layer.open, .profile-layer.open"
let veilSelector = ".letter-backdrop, .sponsor-backdrop, .profile-backdrop"

func setUpDuo() {
    func band() -> Double {
        guard includes(global.navigator.userAgent.string ?? "", "iPhone"), decimal(global.navigator.maxTouchPoints) >= 2 else { return 0 }
        // clientWidth, not innerWidth: on iPhone innerWidth shrinks with pinch zoom and looked like the Duo's strip
        let g = (decimal(global.screen.width) - decimal(document.documentElement.clientWidth)).rounded()
        return g >= 40 && g <= 200 ? g : 0
    }
    var edge: JSValue? = nil, signature = ""
    let root = document.documentElement, body = document.body

    func teardown() {
        guard let b = edge else { return }
        _ = b.remove(); edge = nil; signature = ""
        for e in jsArray(document.querySelectorAll("[data-right-radius]")) { e.style.borderTopRightRadius = ""; _ = e.removeAttribute("data-right-radius") }
        root.style.touchAction = ""; body.style.touchAction = ""
        root.style.overflowX = ""; body.style.overflowX = ""
        _ = root.style.removeProperty("--duo")
    }

    func make() {
        let scale = global.visualViewport.object != nil ? decimal(global.visualViewport.scale) : 1
        guard abs(scale - 1) < 0.01 else { return }   // zoomed in: leave everything as it is until it's back
        let b = band()
        guard b > 0 else { teardown(); return }
        _ = root.style.setProperty("--duo", px(b))   // the fixed bar reaches into the strip too (CSS)
        let width = decimal(document.documentElement.clientWidth), height = decimal(root.scrollHeight), shifted = decimal(global.scrollY)
        let hero = byId("hero")
        let sections = ([hero] + jsArray(document.querySelectorAll("main > section")) + [document.querySelector("footer")]).filter { $0.object != nil }
        let metrics = sections.map { e -> (Int, Int) in let r = Box(e); return (Int((r.top + shifted).rounded()), Int(r.height.rounded())) }
        let grid: JSValue = hero.object != nil ? global.getComputedStyle(hero, "::before") : .null
        let layer = document.querySelector(openLayerSelector)
        let veil: JSValue = layer.object != nil ? layer.querySelector(veilSelector) : .null
        if !sameText(root.style.overflowX.string ?? "", "hidden") && !sameText(root.style.overflow.string ?? "", "hidden") { root.style.overflowX = "hidden" }
        let updated = [jsNumber(b), jsNumber(width), jsNumber(height), metrics.map { "\($0.0),\($0.1)" }.joined(separator: ";"),
                     grid.object != nil ? (grid.opacity.string ?? "") : "", veil.object != nil ? "v\(Int(shifted.rounded()))" : ""].joined(separator: "|")
        guard !sameText(updated, signature) else { return }
        signature = updated
        if edge == nil {
            root.style.overflowX = "hidden"
            body.style.overflowX = "visible"   // the body normally clips horizontally; the column must stick out
            root.style.touchAction = "pan-y pinch-zoom"; body.style.touchAction = "pan-y pinch-zoom"
            let fresh = document.createElement("div")
            _ = fresh.setAttribute("aria-hidden", "true")
            _ = body.appendChild(fresh)
            edge = fresh
        }
        guard let column = edge else { return }
        column.style.cssText = .string("position:absolute;top:0;left:" + px(width) + ";width:" + px(b) + ";height:" + px(height)
            + ";overflow:clip;pointer-events:none;z-index:0;background:" + (global.getComputedStyle(body).backgroundColor.string ?? ""))
        _ = column.replaceChildren()
        for (i, section) in sections.enumerated() {
            let computedStyle = global.getComputedStyle(section), (top, height) = metrics[i]
            let piece = document.createElement("div")
            piece.style.cssText = .string("position:absolute;left:0;width:100%;top:\(top)px;height:\(height)px")
            let background = computedStyle.backgroundColor.string ?? "", image = computedStyle.backgroundImage.string ?? "none"
            if !sameText(background, "rgba(0, 0, 0, 0)") { piece.style.backgroundColor = .string(background) }
            if !sameText(image, "none") { piece.style.backgroundImage = .string(image) }
            let radius = section.dataset.rightRadius.string ?? (computedStyle.borderTopRightRadius.string ?? "")
            let r = decimal(global.parseFloat(radius))
            if r != 0 { section.dataset.rightRadius = .string(radius); section.style.borderTopRightRadius = "0"; piece.style.borderTopRightRadius = .string(radius) }
            if isSame(section, hero) && grid.object != nil {
                let size = grid.backgroundSize.string ?? "", step = decimal(global.parseFloat(size)) == 0 ? 24 : decimal(global.parseFloat(size))
                let x0 = (decimal(section.clientWidth) - step) / 2
                let phase = ((x0 - width).truncatingRemainder(dividingBy: step) + step).truncatingRemainder(dividingBy: step)
                let mask = grid.webkitMaskImage.string ?? (grid.maskImage.string ?? "")
                let dots = document.createElement("div")
                dots.style.cssText = .string("position:absolute;inset:0;background-image:" + (grid.backgroundImage.string ?? "") + ";background-size:" + size + ";"
                    + "background-position:" + px(phase) + " 0;opacity:" + (grid.opacity.string ?? "") + ";-webkit-mask-image:"
                    + (mask.isEmpty ? (grid.maskImage.string ?? "") : mask) + ";mask-image:" + (grid.maskImage.string ?? ""))
                _ = piece.appendChild(dots)
            }
            _ = column.appendChild(piece)
        }
        if veil.object != nil {
            // The popup is fixed and doesn't reach the strip, so its veil is painted here, screen-high.
            let v = document.createElement("div")
            v.style.cssText = .string("position:absolute;left:0;width:100%;top:\(Int(shifted.rounded()) - 200)px;height:"
                + px(decimal(global.screen.height) + 400) + ";z-index:2;background:" + (global.getComputedStyle(veil).backgroundColor.string ?? ""))
            _ = column.appendChild(v)
        }
    }

    // With a popup open the page is locked (overflow:hidden) and Safari paints the strip and the area under its bar with
    // the body background, so the body takes the veil colour blended over the section underneath until it closes.
    var tinted = false
    func tint() {
        let layer = document.querySelector(openLayerSelector)
        let veil: JSValue = layer.object != nil ? layer.querySelector(veilSelector) : .null
        guard veil.object != nil else {
            if tinted { body.style.backgroundColor = ""; tinted = false }
            return
        }
        let shifted = decimal(global.scrollY), middle = shifted + viewportHeight() / 2
        let section = jsArray(document.querySelectorAll("#hero, main > section, footer")).first { e in
            let r = Box(e); return r.top + shifted <= middle && r.bottom + shifted > middle
        }
        var base = colorComponents(section.map { global.getComputedStyle($0).backgroundColor.string ?? "" } ?? "")
        if base.count >= 4 && base[3] == 0 { base = [247, 247, 247, 1] }
        if base.count < 3 { base = [0, 0, 0] }
        let color = colorComponents(global.getComputedStyle(veil).backgroundColor.string ?? "")
        let a = color.count >= 4 ? color[3] : 1
        let mix = (0..<3).map { i in Int(((i < color.count ? color[i] : 0) * a + base[i] * (1 - a)).rounded()) }
        body.style.backgroundColor = .string("rgb(\(mix[0]),\(mix[1]),\(mix[2]))"); tinted = true
    }

    listen(global, "load") { _ in make() }
    listen(global, "resize") { _ in signature = ""; make() }
    _ = global.setInterval(closure { _ in tint(); make() }, 200)
    make()
}
