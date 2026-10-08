const mongoose = require('mongoose');
const request = require('supertest');
const { createApp } = require('../src/app');
const User = require('../src/models/User');

const app = createApp();
let counter = 0;

async function connect() {
  await mongoose.connect(process.env.MONGO_URI);
}

async function disconnect() {
  if (mongoose.connection.readyState === 1) await mongoose.connection.dropDatabase();
  await mongoose.disconnect();
}

async function clearDb() {
  const collections = await mongoose.connection.db.collections();
  await Promise.all(collections.map((c) => c.deleteMany({})));
}

// Registers a user through the API (or creates an admin directly) and
// returns { token, user, id, api } where api(method, path) is pre-authed.
async function makeUser(role = 'client', extra = {}) {
  counter += 1;
  const email = `${role}${counter}_${Date.now()}@test.com`;
  const password = 'secret123';
  if (role === 'admin') {
    await User.create({ name: `Admin ${counter}`, email, password, role: 'admin' });
  } else {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ name: `${role} ${counter}`, email, password, role, ...(extra.register || {}) });
    if (res.status !== 201) throw new Error(`register failed: ${res.status} ${JSON.stringify(res.body)}`);
  }
  if (extra.profile) await User.updateOne({ email }, { $set: extra.profile });
  const login = await request(app).post('/api/auth/login').send({ email, password });
  const { token, user } = login.body;
  const api = (method, path) => request(app)[method](path).set('Authorization', `Bearer ${token}`);
  return { token, user, id: user.id, email, password, api };
}

module.exports = { app, request, connect, disconnect, clearDb, makeUser };
