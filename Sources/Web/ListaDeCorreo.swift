// La lista de correo: los formularios para apuntarse (el del hero, «Avísame» y el de cada quedada) mandan el email a
// EmailOctopus, al mismo sitio al que lo mandaría su formulario incrustado, pero sin cargar su script, sus estilos ni
// Google: la página sigue igual y no se instalan cookies.
//
// Cómo envía su formulario (visto en su script, noviembre de 2026): un POST urlencoded a `formulario`, con el email en
// `field_0` y un campo trampa que tiene que ir vacío. Responde JSON: {"success": true, …} o {"error": {"code": …}}.
// La doble confirmación la hace EmailOctopus: manda el email de «Confirmar mi email» y hasta entonces no cuenta.
//
// Si se rehace el formulario en EmailOctopus (Grow › Forms), cambia su id: hay que copiarlo aquí desde
// «Add to your website» (data-form="…") y volver a compilar el WebAssembly.

import HolaSwift
import JavaScriptKit

enum ListaDeCorreo {
    static let formulario = "https://eomail5.com/form/c5298ac6-d704-11f1-8041-0903c3f30cab"
    /// El campo trampa de su formulario: los bots lo rellenan y EmailOctopus los descarta.
    static let trampa = "hpc4b27b6e-eb38-11e9-be00-06b4694bee2a"
    /// El campo del formulario de EmailOctopus donde se guarda de dónde viene cada persona (`web`, `avisame`,
    /// `quedada-2027-01`…). Vacío mientras el formulario no tenga ese campo: entonces solo se manda el email.
    static let campoOrigen = ""
}

/// Apunta un email a la lista. `listo` recibe true si EmailOctopus lo ha aceptado (le llegará el correo para confirmar).
/// `trampa` es lo que haya en el campo oculto de nuestro formulario: si un bot lo rellena, se reenvía y EmailOctopus lo descarta.
func apuntar(_ email: String, origen: String, trampa: String, listo: @escaping (Bool) -> Void) {
    guard let crear = global.URLSearchParams.object else { listo(false); return }
    let datos = JSValue.object(crear.new())
    _ = datos.set("field_0", email)
    _ = datos.set(ListaDeCorreo.trampa, trampa)
    if !ListaDeCorreo.campoOrigen.isEmpty { _ = datos.set(ListaDeCorreo.campoOrigen, origen) }

    guard global.object?["fetch"].function != nil else { listo(false); return }
    let peticion = global.fetch(ListaDeCorreo.formulario, objetoJS([
        ("method", .string("POST")), ("mode", .string("cors")), ("cache", .string("no-cache")), ("body", datos),
    ]))
    let fallo = closure { _ in listo(false) }
    _ = peticion.then(closure { respuesta in
        guard respuesta.object?["json"].function != nil else { listo(false); return }
        _ = respuesta.json().then(closure { json in listo(json.object?["success"].boolean == true) }, fallo)
    }, fallo)
}

/// El texto del campo trampa de un formulario (vacío si no lo tiene).
func trampa(en formulario: JSValue) -> String {
    let campo = buscar(".trampa", en: formulario)
    return campo.object == nil ? "" : (campo.value.string ?? "")
}

let sinConexion = "No hemos podido apuntarte. Revisa tu conexión e inténtalo de nuevo."
