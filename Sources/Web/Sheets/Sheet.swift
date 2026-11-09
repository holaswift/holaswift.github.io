import HolaSwift
import JavaScriptKit

/// A modal layer of the page: profile, “Avísame”, sponsorship or session card.
///
/// It handles what they share: appearing with its CSS animation (Swift only toggles `hidden` and the `open` class),
/// closing with Esc or a click outside, keeping the rest of the page `inert` while open so Tab can't escape, and giving
/// focus back to whatever opened it.
final class Sheet {
    let layer: JSValue
    let closeMs: Int
    var returnTo: JSValue = .undefined
    var focusElement: JSValue = .undefined
    var isOpen: Bool { layer.hidden.boolean == false }
    var enter: JSValue = .undefined, animate: JSValue = .undefined, hide: JSValue = .undefined
    var restoreFocus: JSValue = .undefined, focusTarget: JSValue = .undefined
    /// Runs right before closing, such as the profile flying back to its card.
    var onClose: (() -> Void)? = nil

    /// - Parameter closeMs: How long the CSS exit animation lasts; the layer is hidden after it.
    init?(_ id: String, closeMs: Int) {
        layer = byId(id)
        guard layer.object != nil else { return nil }
        self.closeMs = closeMs
        enter = closure { _ in _ = self.layer.classList.add("open") }
        animate = closure { _ in _ = global.requestAnimationFrame(self.enter) }   // two frames, so CSS sees the unhidden state first
        // Scrolling is given back only once hidden: if the page moved during the flight back, the card would land where
        // its slot used to be. Does nothing if it was reopened meanwhile.
        hide = closure { _ in
            guard !(self.layer.classList.contains("open").boolean ?? false) else { return }
            self.layer.hidden = .boolean(true)
            document.documentElement.style.overflow = ""
        }
        restoreFocus = closure { _ in focusIfPossible(self.returnTo) }
        focusTarget = closure { _ in focusIfPossible(self.focusElement) }
        _ = document.body.appendChild(layer)
        let observer = global.MutationObserver.object!.new(closure { _ in self.updateInert() })
        let filterList = global.Array.object!.new()
        _ = JSValue.object(filterList).push("hidden", "class")
        _ = JSValue.object(observer).observe(layer, jsObject([("attributes", .boolean(true)), ("attributeFilter", .object(filterList))]))
    }

    func updateInert() {
        let isOpen = self.isOpen && (layer.classList.contains("open").boolean ?? false)
        for el in jsArray(document.body.children) {
            if isSame(el, layer) || sameText(el.tagName.string ?? "", "SCRIPT") || sameText(el.id.string ?? "", "carta") { continue }
            el.inert = .boolean(isOpen)
        }
    }

    func show(focusElement: JSValue, wait: Bool = false) {
        returnTo = document.activeElement
        self.focusElement = focusElement
        layer.hidden = .boolean(false)
        document.documentElement.style.overflow = "hidden"
        _ = global.requestAnimationFrame(animate)
        if wait { _ = global.setTimeout(focusTarget, isStatic ? 0 : 350) } else { focusIfPossible(focusElement) }
    }

    func close() {
        guard isOpen else { return }
        onClose?()
        _ = layer.classList.remove("open")
        _ = global.setTimeout(hide, isStatic ? 0 : closeMs)
        _ = global.setTimeout(restoreFocus, 0)
    }

    func closeOnOutsideClick(background: String) {
        listen(layer, "click") { e in
            if isSame(e.target, self.layer) || (e.target.classList.contains(background).boolean ?? false) { self.close() }
        }
    }
}
