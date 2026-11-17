import HolaSwift
import JavaScriptKit

/// `nil` where nothing is frozen (mouse, or no svh support).
var frozenViewportHeight: Double? = nil

/// In-app browsers (the Google app, Instagram, Android WebViews…) resize the page with their bars, so svh, lvh and vh
/// changed on every scroll and the page jumped. Safari already keeps them still, so freezing changes nothing there.
/// With a mouse, resizing the window has to keep reflowing.
func setUpStableViewport() {
    guard global.matchMedia("(pointer:coarse)").matches.boolean == true,
          global.CSS.object != nil, global.CSS.supports("height", "1svh").boolean == true else { return }
    let root = document.documentElement
    func probe(_ unit: String) -> JSValue {
        let p = document.createElement("div")
        _ = p.setAttribute("aria-hidden", "true")
        p.style.cssText = .string("position:fixed;top:0;left:0;width:0;height:100" + unit + ";visibility:hidden;pointer-events:none")
        _ = document.body.appendChild(p)
        return p
    }
    // Real units, not the variables: with the variables they would only read back the frozen values.
    let small = probe("svh"), large = probe("lvh")
    var width = -1.0
    func freeze() {
        let s = Box(small).height, l = Box(large).height
        guard s > 0, l > 0 else { return }
        _ = root.style.setProperty("--svh", px(s / 100))
        _ = root.style.setProperty("--lvh", px(l / 100))
        frozenViewportHeight = s
    }
    func widthChanged() {
        let w = decimal(root.clientWidth)
        guard w != width else { return }
        width = w
        freeze()
        // On rotation some browsers fire resize before their bars settle into the new orientation.
        _ = global.setTimeout(closure { _ in freeze() }, 500)
    }
    widthChanged()
    listen(global, "resize") { _ in widthChanged() }
}
