const mongoose = require('mongoose');

// A conversation is (job, client, technician): the client can talk to any
// technician who bid on / was requested for / is assigned to the job.
const messageSchema = new mongoose.Schema(
  {
    job: { type: mongoose.Schema.Types.ObjectId, ref: 'Job', required: true, index: true },
    sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    recipient: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    text: { type: String, default: '' },
    image: { type: String, default: '' },
    readAt: { type: Date, default: null }
  },
  { timestamps: true }
);

messageSchema.index({ job: 1, sender: 1, recipient: 1, createdAt: 1 });

module.exports = mongoose.model('Message', messageSchema);
