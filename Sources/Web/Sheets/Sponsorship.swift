// The sponsorship form: sends the message to a Google Apps Script in the equipo@holaswift.com account
// (scripts/sponsorship.gs), which forwards it to patrocinio@holaswift.com with the reply set to the company.
//
// While `url` is empty, the form opens the mail app with the message already written, so none gets lost.

import HolaSwift
import JavaScriptKit

enum Sponsorship {
    /// The /exec URL of the Apps Script web app (Deploy › Manage deployments).
    static let url = "https://script.google.com/macros/s/AKfycbytvm6sTSnIEQXZ4leVWldwYhgnodUOiE6SGO_05fGVhzaavw_m5vIQz2WbovDTxpZw/exec"
    static let email = "patrocinio@holaswift.com"
}

/// Sends the sponsorship message.
/// - Parameter ready: Called with `true` if the message went out.
func sendSponsorship(name: String, company: String, email: String, message: String, honeypot: String,
                      ready: @escaping (Bool) -> Void) {
    if Sponsorship.url.isEmpty {
        let subject = "Patrocinio: " + name + (company.isEmpty ? "" : " · " + company)
        let body = message + "\n\n" + name + (company.isEmpty ? "" : " · " + company) + "\n" + email
        let link = "mailto:" + Sponsorship.email + "?subject=" + (global.encodeURIComponent(subject).string ?? "")
            + "&body=" + (global.encodeURIComponent(body).string ?? "")
        global.location.href = .string(link)
        ready(true)
        return
    }
    guard let create = global.URLSearchParams.object, global.object?["fetch"].function != nil else { ready(false); return }
    let info = JSValue.object(create.new())
    for (key, value) in [("nombre", name), ("empresa", company), ("email", email), ("mensaje", message), ("web", honeypot)] {
        _ = info.set(key, value)
    }
    let failure = closure { _ in ready(false) }
    _ = global.fetch(Sponsorship.url, jsObject([("method", .string("POST")), ("body", info)])).then(closure { response in
        guard response.object?["json"].function != nil else { ready(false); return }
        _ = response.json().then(closure { json in ready(json.object?["ok"].boolean == true) }, failure)
    }, failure)
}
