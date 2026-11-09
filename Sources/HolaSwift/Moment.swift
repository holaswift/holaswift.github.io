/// An instant with its calendar parts already in Spanish time (Europe/Madrid).
///
/// Whoever has a clock builds it: the generator with Foundation, the page with `Intl`. That keeps this module free of
/// Foundation and makes both sides compute the same results.
public struct Moment {
    public let ms: Double
    public let year, month, day, hour, minute: Int

    public init(ms: Double, year: Int, month: Int, day: Int, hour: Int, minute: Int) {
        self.ms = ms; self.year = year; self.month = month; self.day = day; self.hour = hour; self.minute = minute
    }

    public var dayNumber: Int { year * 10_000 + month * 100 + day }
    public var hourMinute: String { twoDigits(hour) + ":" + twoDigits(minute) }
}

func twoDigits(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
