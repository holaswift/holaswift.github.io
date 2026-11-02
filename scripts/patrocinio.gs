// El formulario de patrocinio de holaswift.com: recibe el mensaje y lo manda a patrocinio@holaswift.com.
//
// Es un Google Apps Script que vive en la cuenta equipo@holaswift.com (script.google.com), no en la web.
// Este archivo es la copia de referencia: si se cambia aquí, hay que pegarlo allí y publicar una versión nueva
// (Implementar › Gestionar implementaciones › editar › Versión: nueva). La URL /exec no cambia.
//
// Implementación: Implementar › Nueva implementación › Aplicación web, «Ejecutar como: yo» y
// «Quién tiene acceso: cualquier usuario». La URL que da (…/exec) va en Sources/Web/Patrocinio.swift.

const DESTINO = 'patrocinio@holaswift.com';
const ETIQUETA = 'Patrocinio';   // la etiqueta de Gmail; si no existe, se crea

function doPost(e) {
  const p = (e && e.parameter) || {};
  const responder = (ok) => ContentService
    .createTextOutput(JSON.stringify({ ok: ok }))
    .setMimeType(ContentService.MimeType.JSON);

  // Campo trampa: las personas no lo ven; si viene relleno, es un bot. Se le dice que sí y no se manda nada.
  if (p.web) return responder(true);

  const corta = (t, n) => String(t || '').trim().slice(0, n);
  const nombre = corta(p.nombre, 200);
  const empresa = corta(p.empresa, 200);
  const email = corta(p.email, 320);
  const mensaje = corta(p.mensaje, 5000);
  if (!nombre || !mensaje || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return responder(false);

  const asunto = 'Patrocinio: ' + nombre + (empresa ? ' · ' + empresa : '');
  const cuerpo = 'Nombre: ' + nombre + '\n'
      + 'Empresa: ' + (empresa || '—') + '\n'
      + 'Email: ' + email + '\n\n'
      + mensaje + '\n\n'
      + '—\nEnviado desde el formulario de patrocinio de holaswift.com. Responde a este correo para contestar a ' + nombre + '.';

  // patrocinio@ es un alias de la cuenta que ejecuta el script: Gmail guarda el correo como enviado y no lo pasa por
  // Recibidos. Por eso se envía como borrador (que devuelve el mensaje) y luego se mueve a Recibidos, sin leer y con etiqueta.
  const enviado = GmailApp.createDraft(DESTINO, asunto, cuerpo, { replyTo: email, name: 'Web hola Swift' }).send();
  const hilo = enviado.getThread();
  hilo.moveToInbox();
  hilo.markUnread();
  hilo.addLabel(GmailApp.getUserLabelByName(ETIQUETA) || GmailApp.createLabel(ETIQUETA));
  return responder(true);
}
