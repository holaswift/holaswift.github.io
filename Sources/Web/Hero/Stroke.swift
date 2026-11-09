import HolaSwift
import JavaScriptKit

final class Stroke {
    let length: Double
    let offset: Cached<Double>
    let nodes: [(Double, Cached<Bool>)]
    init(white: JSValue, shadow: JSValue, nodes: [JSValue]) {
        length = decimal(white.getTotalLength())
        let dashes = jsNumber(length) + " " + jsNumber(length)
        white.style.strokeDasharray = .string(dashes); shadow.style.strokeDasharray = .string(dashes)
        offset = Cached { d in white.style.strokeDashoffset = .number(d); shadow.style.strokeDashoffset = .number(d) }
        self.nodes = nodes.map { g in (decimal(g.dataset.f), Cached<Bool> { on in _ = g.classList.toggle("on", on) }) }
    }
}
