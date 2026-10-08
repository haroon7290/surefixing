const http = require('http');
const mongoose = require('mongoose');
const config = require('./config');
const { createApp } = require('./app');
const realtime = require('./utils/realtime');

const app = createApp();
const httpServer = http.createServer(app);
realtime.init(httpServer);

mongoose
  .connect(config.mongoUri)
  .then(() => {
    console.log('MongoDB connected');
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
