// Tells the start scripts what state the database is in, through the exit
// code:  0 = empty · 1 = has data · 2 = cannot connect · 3 = data from an
// older SureFix version (it will not work with this one until reset).
const mongoose = require('mongoose');
const config = require('../config');

mongoose
  .connect(config.mongoUri, { serverSelectionTimeoutMS: 4000 })
  .then(async () => {
    const db = mongoose.connection.db;
    const users = await db.collection('users').countDocuments();
    if (users === 0) process.exit(0);
    // v3 renamed the activity-log field and made `supplier` required on rentals.
    const oldJob = await db.collection('jobs').findOne({ 'history.status': { $exists: true } });
    const oldRental = await db.collection('rentals').findOne({ supplier: { $exists: false } });
    process.exit(oldJob || oldRental ? 3 : 1);
  })
  .catch(() => process.exit(2));
