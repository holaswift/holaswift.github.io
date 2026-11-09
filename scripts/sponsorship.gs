// The holaswift.com sponsorship form: receives the message and sends it to patrocinio@holaswift.com.
//
// It's a Google Apps Script that lives in the equipo@holaswift.com account (script.google.com), not in the website.
// This file is the reference copy: if it changes here, paste it there and publish a new version
// (Deploy › Manage deployments › edit › Version: new). The /exec URL doesn't change.
//
// Deployment: Deploy › New deployment › Web app, "Execute as: me" and
// "Who has access: anyone". The URL it gives (…/exec) goes in Sources/Web/Sheets/Sponsorship.swift.
//
// The request fields (nombre, empresa, email, mensaje, web) are what Sources/Web/Sheets/Sponsorship.swift sends: keep both in sync.

const RECIPIENT = 'patrocinio@holaswift.com';
const LABEL = 'Patrocinio';   // the Gmail label; created if it doesn't exist

function doPost(e) {
  const p = (e && e.parameter) || {};
  const reply = (ok) => ContentService
    .createTextOutput(JSON.stringify({ ok: ok }))
    .setMimeType(ContentService.MimeType.JSON);

  // Honeypot field: people don't see it; if it comes filled in, it's a bot. Say yes and send nothing.
  if (p.web) return reply(true);

  const clip = (t, n) => String(t || '').trim().slice(0, n);
  const name = clip(p.nombre, 200);
  const company = clip(p.empresa, 200);
  const email = clip(p.email, 320);
  const message = clip(p.mensaje, 5000);
  if (!name || !message || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return reply(false);

  const subject = 'Patrocinio: ' + name + (company ? ' · ' + company : '');
  const body = 'Nombre: ' + name + '\n'
      + 'Empresa: ' + (company || '—') + '\n'
      + 'Email: ' + email + '\n\n'
      + message + '\n\n'
      + '—\nEnviado desde el formulario de patrocinio de holaswift.com. Responde a este correo para contestar a ' + name + '.';

  // patrocinio@ is an alias of the account running the script: Gmail stores the email as sent and doesn't put it in the
  // Inbox. So it's sent as a draft (which returns the message) and then moved to the Inbox, unread and labelled.
  const sent = GmailApp.createDraft(RECIPIENT, subject, body, { replyTo: email, name: 'Web hola Swift' }).send();
  const thread = sent.getThread();
  thread.moveToInbox();
  thread.markUnread();
  thread.addLabel(GmailApp.getUserLabelByName(LABEL) || GmailApp.createLabel(LABEL));
  return reply(true);
}
