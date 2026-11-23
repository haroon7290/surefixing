const http = require('http');
const mongoose = require('mongoose');
const config = require('./config');
const { createApp } = require('./app');
const realtime = require('./utils/realtime');
const firebase = require('./utils/firebase');
const User = require('./models/User');
const Job = require('./models/Job');
const Rental = require('./models/Rental');

const app = createApp();
const httpServer = http.createServer(app);
realtime.init(httpServer);

mongoose
  .connect(config.mongoUri)
  .then(() => {
    console.log('MongoDB connected');
    Job.numberMissing()
      .then((n) => n && console.log(`Gave job numbers to ${n} older jobs`))
      .catch((err) => console.error('Job numbering failed:', err.message));
    Rental.migrateInstallments()
      .then(async (n) => {
        if (n) console.log(`Turned ${n} installment plans into one-time purchases`);
        const numbered = await Rental.numberMissing();
        if (numbered) console.log(`Gave invoice numbers to ${numbered} older rentals`);
      })
      .catch((err) => console.error('Rental upgrade failed:', err.message));
    // Copy accounts that aren't in Firebase yet (keeps their passwords).
    if (firebase.canManage()) {
      firebase
        .syncUsers(User)
        .then((r) => (r.imported || r.linked || r.failed) && console.log(`Firebase: ${r.imported} accounts copied, ${r.linked} linked, ${r.failed} failed`))
        .catch((err) => console.error('Firebase sync failed:', err.message));
    }
    httpServer.listen(config.port, () =>
      console.log(`SureFix backend (HTTP + Socket.IO) running on http://localhost:${config.port}`)
    );
  })
  .catch((err) => {
    console.error('Mongo connection failed:', err.message);
    process.exit(1);
  });

function shutdown(signal) {
  console.log(`${signal} received, shutting down…`);
  realtime.close();
  httpServer.close(() => {
    mongoose.disconnect().finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 5000).unref();
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
