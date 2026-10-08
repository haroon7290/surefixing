require('dotenv').config();
const express = require('express');
const http = require('http');
const mongoose = require('mongoose');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
const fs = require('fs');

const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const jobRoutes = require('./routes/jobs');
const toolRoutes = require('./routes/tools');
const messageRoutes = require('./routes/messages');
const kycRoutes = require('./routes/kyc');
const adminRoutes = require('./routes/admin');
const reviewRoutes = require('./routes/reviews');
const realtime = require('./utils/realtime');

const app = express();

const uploadDir = path.resolve(process.env.UPLOAD_DIR || 'uploads');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

app.use(cors());
app.use(express.json({ limit: '5mb' }));
app.use(morgan('dev'));
app.use('/uploads', express.static(uploadDir));

app.get('/', (_req, res) => res.json({ ok: true, service: 'fixit-backend' }));

app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/jobs', jobRoutes);
app.use('/api/tools', toolRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/kyc', kycRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/reviews', reviewRoutes);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(err.status || 500).json({ error: err.message || 'Server error' });
});

const PORT = process.env.PORT || 4000;
const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/fixit';

const httpServer = http.createServer(app);
realtime.init(httpServer);

mongoose
  .connect(MONGO_URI)
  .then(() => {
    console.log('MongoDB connected');
    httpServer.listen(PORT, () =>
      console.log(`Backend (HTTP + Socket.IO) running on http://localhost:${PORT}`)
    );
  })
  .catch((err) => {
    console.error('Mongo connection failed:', err.message);
    process.exit(1);
  });