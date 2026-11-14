const mongoose = require('mongoose');

// Two kinds of conversation:
//   (job, client, technician) — the client can talk to any technician who
//     bid on / was requested for / is assigned to the job;
//   (tool, customer, supplier) — questions before renting or buying, then
//     arranging pickup, delivery and return.
// Every message belongs to exactly one job or one tool.
const messageSchema = new mongoose.Schema(
  {
    job: { type: mongoose.Schema.Types.ObjectId, ref: 'Job', default: null, index: true },
    tool: { type: mongoose.Schema.Types.ObjectId, ref: 'Tool', default: null, index: true },
    sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    recipient: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    text: { type: String, default: '' },
    image: { type: String, default: '' },
    readAt: { type: Date, default: null }
  },
  { timestamps: true }
);

messageSchema.index({ job: 1, sender: 1, recipient: 1, createdAt: 1 });
messageSchema.index({ tool: 1, sender: 1, recipient: 1, createdAt: 1 });

messageSchema.pre('validate', function (next) {
  if (Boolean(this.job) === Boolean(this.tool)) return next(new Error('A message belongs to exactly one job or tool'));
  next();
});

module.exports = mongoose.model('Message', messageSchema);
