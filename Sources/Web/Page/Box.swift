import HolaSwift
import JavaScriptKit

struct Box {
    let left, top, width, height: Double
    var right: Double { left + width }
    var bottom: Double { top + height }
    init(_ el: JSValue) {
        let r = el.object != nil ? el.getBoundingClientRect() : .undefined
        left = decimal(r.left); top = decimal(r.top); width = decimal(r.width); height = decimal(r.height)
    }
}
