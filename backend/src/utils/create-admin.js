// Creates (or resets the password of) a single admin account.
// Unlike seed.js, this NEVER deletes existing data -- safe to run against
// a live database. Run with `npm run create-admin` from backend/.
//
// Usage:
//   node src/utils/create-admin.js
//   node src/utils/create-admin.js --name="Jane Admin" --email=jane@company.com --password="StrongPass123!"

const mongoose = require('mongoose');
const readline = require('readline');
const User = require('../models/User');

const { mongoUri: MONGO_URI } = require('../config');

function parseArgs() {
  const args = {};
  process.argv.slice(2).forEach((arg) => {
    const m = arg.match(/^--([^=]+)=(.*)$/);
    if (m) args[m[1]] = m[2];
  });
  return args;
}

function ask(rl, question) {
  return new Promise((resolve) => rl.question(question, resolve));
}

// Minimal masked prompt for the password (no extra npm dependency needed).
function askHidden(question) {
  return new Promise((resolve) => {
    const stdin = process.stdin;
    process.stdout.write(question);
    let value = '';
    const onData = (buf) => {
      const char = buf.toString('utf8');
      if (char === '\n' || char === '\r' || char === '\u0004') {
        stdin.removeListener('data', onData);
        if (stdin.isTTY) stdin.setRawMode(false);
        stdin.pause();
        process.stdout.write('\n');
        resolve(value);
        return;
      }
      if (char === '\u0003') { process.stdout.write('\n'); process.exit(1); } // Ctrl+C
      if (char === '\u007f' || char === '\b') { value = value.slice(0, -1); return; } // backspace
      value += char;
    };
    if (stdin.isTTY) stdin.setRawMode(true);
    stdin.resume();
    stdin.on('data', onData);
  });
}

async function run() {
  const args = parseArgs();
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

  const name = args.name || (await ask(rl, 'Admin full name: '));
  const email = (args.email || (await ask(rl, 'Admin email: '))).trim().toLowerCase();
  let password = args.password;
  rl.close();
  if (!password) {
    password = await askHidden('Admin password (min 6 chars): ');
  }

  if (!name.trim() || !/^\S+@\S+\.\S+$/.test(email) || password.length < 6) {
    console.error('A name, a valid email, and a password of at least 6 characters are required.');
    process.exit(1);
  }

  await mongoose.connect(MONGO_URI);

  const existing = await User.findOne({ email });
  if (existing) {
    if (existing.role !== 'admin') {
      console.error(`A ${existing.role} account already uses ${email}. Choose a different email.`);
      await mongoose.disconnect();
      process.exit(1);
    }
    existing.password = password; // pre-save hook re-hashes this
    existing.name = name;
    await existing.save();
    console.log(`Updated existing admin account: ${email}`);
  } else {
    await User.create({ name, email, password, role: 'admin' });
    console.log(`Created new admin account: ${email}`);
  }

  await mongoose.disconnect();
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});