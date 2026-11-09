import HolaSwift
import JavaScriptKit

final class Piece {
    let phases: Phases, strokes: [Stroke], total: Double
    let dots: Cached<Bool>, meshProgress: Cached<Double>, color: Cached<Double>, vectorOpacity: Cached<Double>, meshOpacity: Cached<Double>
    let scale: Cached<Double>, visible: Cached<Bool>
    init?(_ phases: Phases) {
        let el = document.querySelector(".el[data-k=\"" + phases.k + "\"]")
        guard el.object != nil else { return nil }
        self.phases = phases
        let whitespaceScalars = jsArray(el.querySelectorAll(".over path")), shadows = jsArray(el.querySelectorAll(".under path"))
        strokes = whitespaceScalars.indices.map { i in
            Stroke(white: whitespaceScalars[i], shadow: i < shadows.count ? shadows[i] : whitespaceScalars[i], nodes: jsArray(el.querySelectorAll(".nodes[data-i=\"\(i)\"] g")))
        }
        total = strokes.reduce(0) { $0 + $1.length }
        let vec = el.querySelector(".vec"), mesh = el.querySelector(".mesh"), col = el.querySelector(".col")
        let circles = jsArray(el.querySelectorAll("circle.dot"))
        dots = Cached { on in for c in circles { c.style.opacity = .number(on ? 1 : 0) } }
        meshProgress = Cached { p in _ = mesh.style.setProperty("--p", p) }
        color = Cached { p in _ = col.style.setProperty("--p", p) }
        vectorOpacity = Cached { o in vec.style.opacity = .number(o) }
        meshOpacity = Cached { o in mesh.style.opacity = .number(o) }
        scale = Cached { s in el.style.transform = .string("scale(" + jsNumber(s) + ")") }
        visible = Cached { v in el.style.visibility = .string(v ? "visible" : "hidden") }
    }

    func draw(_ f: Double) {
        var done = 0.0
        let length = f * total
        for stroke in strokes {
            let d = min(stroke.length, max(0, length - done)); done += stroke.length
            // Not rounded: before the stroke starts the offset must be exactly its length, or the round linecap of a tiny
            // leftover dash is painted as a dot at the start.
            stroke.offset.set(stroke.length - d)
            for (point, node) in stroke.nodes { node.set(d > 0 && d / stroke.length >= point - 0.02) }
        }
        dots.set(f >= 1)
    }

    func renderFrame(_ t: Double) {
        let m = progress(t, phases.meshProgress), c = progress(t, phases.color)
        draw(smooth(progress(t, phases.stroke)))
        meshProgress.set(round4(smooth(m))); color.set(round4(smooth(c)))
        vectorOpacity.set(round4(m >= 1 ? max(0, 1 - (t - phases.meshProgress.b) / 0.3) : 1))
        meshOpacity.set(round4(c >= 1 ? max(0, 1 - (t - phases.color.b) / 0.3) : 1))
        var s = 1 + 0.06 * spring(t - phases.meshProgress.b) + 0.08 * spring(t - phases.color.b)
        if let jump = phases.jump { s *= springIn(t - jump) }
        scale.set(round4(s)); visible.set(s > 0.001)
    }
}
