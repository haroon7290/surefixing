const mongoose = require('mongoose');

// Running numbers (e.g. job numbers). `next('job')` is atomic, so two jobs
// posted at the same moment never get the same number.
const counterSchema = new mongoose.Schema({ _id: String, seq: { type: Number, default: 0 } }, { versionKey: false });

counterSchema.statics.next = async function next(name, start = 1000) {
  // First use: start the sequence so the first number is start + 1.
  try {
    await this.updateOne({ _id: name }, { $setOnInsert: { seq: start } }, { upsert: true });
  } catch (err) {
    if (err.code !== 11000) throw err; // another request created it first
  }
  const doc = await this.findOneAndUpdate({ _id: name }, { $inc: { seq: 1 } }, { new: true });
  return doc.seq;
};

module.exports = mongoose.model('Counter', counterSchema);
