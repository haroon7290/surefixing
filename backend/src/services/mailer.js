// Outgoing email. With SMTP_URL set, messages are really sent; without it
// (the default for local development) they are printed in the backend
// console so features like password reset still work end to end.
const config = require('../config');

let transport = null;

function getTransport() {
  if (!config.smtpUrl) return null;
  if (!transport) {
    // Loaded lazily so the backend runs without the package unless email is configured.
    const nodemailer = require('nodemailer');
    transport = nodemailer.createTransport(config.smtpUrl);
  }
  return transport;
}

const emailEnabled = () => Boolean(config.smtpUrl);

// Returns true when the message was handed to an SMTP server.
async function send({ to, subject, text }) {
  const smtp = getTransport();
  if (!smtp) {
    if (!config.isTest) console.log(`\n[mail → ${to}] ${subject}\n${text}\n`);
    return false;
  }
  await smtp.sendMail({ from: config.mailFrom, to, subject, text });
  return true;
}

module.exports = { send, emailEnabled };
