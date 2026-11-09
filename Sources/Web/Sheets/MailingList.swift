// The mailing list: every sign-up form (the hero's, “Avísame” and each session's) posts the email straight to
// EmailOctopus, where its embedded form would, without loading its script, styles or Google: no cookies are set.
//
// How its form submits (seen in its script, November 2026): a urlencoded POST to `form`, with the email in `field_0`
// and a honeypot field that must be empty. It answers JSON: {"success": true, …} or {"error": {"code": …}}.
// EmailOctopus handles the double opt-in: it sends “Confirmar mi email” and doesn't count the contact until then.
//
// If the form is rebuilt in EmailOctopus (Grow › Forms), its id changes: copy it here from “Add to your website”
// (data-form="…") and rebuild the WebAssembly.

import HolaSwift
import JavaScriptKit

enum MailingList {
    static let form = "https://eomail5.com/form/c5298ac6-d704-11f1-8041-0903c3f30cab"
    /// The form's honeypot field: bots fill it in and EmailOctopus discards them.
    static let honeypot = "hpc4b27b6e-eb38-11e9-be00-06b4694bee2a"
    /// The EmailOctopus field that stores where each contact signed up (`web`, `avisame`, `presencial`,
    /// `sesion-2027-01`…). Empty while the form has no such field, so only the email is sent.
    static let sourceField = ""
}

/// Adds an email to the mailing list.
/// - Parameters:
///   - origin: Where they signed up, sent in ``MailingList/sourceField`` when it's set.
///   - honeypot: Our form's hidden field, forwarded as is so EmailOctopus discards bots that filled it in.
///   - ready: Called with `true` if EmailOctopus accepted the email (it then sends the confirmation).
func subscribe(_ email: String, origin: String, honeypot: String, ready: @escaping (Bool) -> Void) {
    guard let create = global.URLSearchParams.object else { ready(false); return }
    let info = JSValue.object(create.new())
    _ = info.set("field_0", email)
    _ = info.set(MailingList.honeypot, honeypot)
    if !MailingList.sourceField.isEmpty { _ = info.set(MailingList.sourceField, origin) }

    guard global.object?["fetch"].function != nil else { ready(false); return }
    let request = global.fetch(MailingList.form, jsObject([
        ("method", .string("POST")), ("mode", .string("cors")), ("cache", .string("no-cache")), ("body", info),
    ]))
    let failure = closure { _ in ready(false) }
    _ = request.then(closure { response in
        guard response.object?["json"].function != nil else { ready(false); return }
        _ = response.json().then(closure { json in ready(json.object?["success"].boolean == true) }, failure)
    }, failure)
}

/// The text in a form's `.honeypot` field, or empty if it has none.
func honeypot(inside form: JSValue) -> String {
    let field = find(".honeypot", inside: form)
    return field.object == nil ? "" : (field.value.string ?? "")
}

let offlineMessage = "No hemos podido apuntarte. Revisa tu conexión e inténtalo de nuevo."
