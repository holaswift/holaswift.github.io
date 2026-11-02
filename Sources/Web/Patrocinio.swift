// El formulario de patrocinio: manda el mensaje a un Google Apps Script de la cuenta equipo@holaswift.com
// (scripts/patrocinio.gs), que lo reenvía a patrocinio@holaswift.com con la respuesta a la empresa.
//
// Mientras `url` esté vacía, el formulario abre el programa de correo con el mensaje ya escrito, para que no se
// pierda ninguno.

import HolaSwift
import JavaScriptKit

enum Patrocinio {
    /// La URL /exec de la aplicación web de Apps Script (Implementar › Gestionar implementaciones).
    static let url = "https://script.google.com/macros/s/AKfycbytvm6sTSnIEQXZ4leVWldwYhgnodUOiE6SGO_05fGVhzaavw_m5vIQz2WbovDTxpZw/exec"
    static let correo = "patrocinio@holaswift.com"
}

/// Manda el formulario. `listo` recibe true si el mensaje ha salido.
func enviarPatrocinio(nombre: String, empresa: String, email: String, mensaje: String, trampa: String,
                      listo: @escaping (Bool) -> Void) {
    if Patrocinio.url.isEmpty {
        let asunto = "Patrocinio: " + nombre + (empresa.isEmpty ? "" : " · " + empresa)
        let cuerpo = mensaje + "\n\n" + nombre + (empresa.isEmpty ? "" : " · " + empresa) + "\n" + email
        let enlace = "mailto:" + Patrocinio.correo + "?subject=" + (global.encodeURIComponent(asunto).string ?? "")
            + "&body=" + (global.encodeURIComponent(cuerpo).string ?? "")
        global.location.href = .string(enlace)
        listo(true)
        return
    }
    guard let crear = global.URLSearchParams.object, global.object?["fetch"].function != nil else { listo(false); return }
    let datos = JSValue.object(crear.new())
    for (clave, valor) in [("nombre", nombre), ("empresa", empresa), ("email", email), ("mensaje", mensaje), ("web", trampa)] {
        _ = datos.set(clave, valor)
    }
    let fallo = closure { _ in listo(false) }
    _ = global.fetch(Patrocinio.url, objetoJS([("method", .string("POST")), ("body", datos)])).then(closure { respuesta in
        guard respuesta.object?["json"].function != nil else { listo(false); return }
        _ = respuesta.json().then(closure { json in listo(json.object?["ok"].boolean == true) }, fallo)
    }, fallo)
}
