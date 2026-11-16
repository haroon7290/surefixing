const mongoose = require('mongoose');

// Three kinds of conversation:
//   (job, client, technician) — the client can talk to any technician who
//     bid on / was requested for / is assigned to the job;
//   (tool, customer, supplier) — questions before renting or buying, then
//     arranging pickup, delivery and return;
//   (support, user) — a user and the SureFix team. Any admin can write or
//     reply; the user only ever sees "SureFix Support". Messages from the
//     user have no recipient (the whole team receives them).
// Every message belongs to exactly one job, tool or support thread.
const messageSchema = new mongoose.Schema(
  {
    job: { type: mongoose.Schema.Types.ObjectId, ref: 'Job', default: null, index: true },
    tool: { type: mongoose.Schema.Types.ObjectId, ref: 'Tool', default: null, index: true },
    // The user whose support conversation this is.
    support: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null, index: true },
    sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    recipient: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
      index: true,
      required() {
        return !this.support;
      }
    },
    // Support messages from the team: what it is about ("Job: Fix sink").
    about: { type: String, default: '', maxlength: 140 },
    text: { type: String, default: '' },
    image: { type: String, default: '' },
    readAt: { type: Date, default: null }
  },
  { timestamps: true }
);

messageSchema.index({ job: 1, sender: 1, recipient: 1, createdAt: 1 });
messageSchema.index({ tool: 1, sender: 1, recipient: 1, createdAt: 1 });

messageSchema.index({ support: 1, createdAt: 1 });

messageSchema.pre('validate', function (next) {
  const kinds = [this.job, this.tool, this.support].filter(Boolean).length;
  if (kinds !== 1) return next(new Error('A message belongs to exactly one job, tool or support conversation'));
  next();
});

module.exports = mongoose.model('Message', messageSchema);
