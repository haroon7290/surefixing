// Rental and installment-purchase lifecycle. Suppliers approve, decline and
// take tools back; renters cancel pending requests, pay installments and
// review finished rentals. See models/Rental.js for the states.
const express = require('express');
const mongoose = require('mongoose');
const { body } = require('express-validator');
const Rental = require('../models/Rental');
const Tool = require('../models/Tool');
const User = require('../models/User');
const { authRequired } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { notify } = require('../utils/notify');
const realtime = require('../utils/realtime');
const wallet = require('../services/wallet');
const { serializeRental, populateRental, listRentals, lateDaysAt, DAY_MS } = require('../services/rentals');
const { paginate, setTotal, sameId, badRequest, forbidden, notFound, conflict } = require('../utils/http');

const router = express.Router();

async function loadRental(id) {
  if (!mongoose.isValidObjectId(id)) throw notFound('Rental not found');
  const rental = await Rental.findById(id).populate('tool');
  if (!rental) throw notFound('Rental not found');
  return rental;
}

function assertSupplier(rental, user) {
  if (user.role !== 'admin' && !sameId(rental.supplier, user._id)) throw forbidden('Only the tool owner can do this');
}

function assertRenter(rental, user) {
  if (!sameId(rental.renter, user._id)) throw forbidden('Not your rental');
}

const toolName = (rental) => rental.tool?.name || 'the tool';

function push(rental) {
  for (const id of [rental.renter, rental.supplier]) {
    realtime.emit(id, 'rental:update', { rentalId: rental._id, status: rental.status });
  }
}

async function respond(res, rental) {
  const fresh = await populateRental(Rental.findById(rental._id));
  res.json(serializeRental(fresh));
}

// ?as=renter (default) | supplier   ?status=requested,active
router.get('/', authRequired, async (req, res) => {
  const filter = req.query.as === 'supplier' ? { supplier: req.user._id } : { renter: req.user._id };
  if (req.query.status) filter.status = { $in: String(req.query.status).split(',') };
  const { limit, skip } = paginate(req, { defaultLimit: 50 });
  const { items, total } = await listRentals(filter, { skip, limit });
  setTotal(res, total);
  res.json(items);
});

router.get('/:id', authRequired, async (req, res) => {
  const rental = await loadRental(req.params.id);
  const allowed = sameId(rental.renter, req.user._id) || sameId(rental.supplier, req.user._id) || req.user.role === 'admin';
  if (!allowed) throw forbidden('Not your rental');
  await respond(res, rental);
});

router.post('/:id/approve', authRequired, async (req, res) => {
  const rental = await loadRental(req.params.id);
  assertSupplier(rental, req.user);
  if (rental.status !== 'requested') throw badRequest(`This request is already ${rental.status}`);

  // A pickup needs somewhere to pick up from: the customer gets this address.
  const supplier = await User.findById(rental.supplier).select('address');
  if (rental.fulfillment === 'pickup' && !supplier?.address) {
    throw badRequest('Add your shop / pickup address in Edit profile first, so the customer knows where to collect the tool');
  }

  // Reserve one unit atomically so two approvals can't oversell the last one.
  const tool = await Tool.findOneAndUpdate({ _id: rental.tool._id, stock: { $gt: 0 } }, { $inc: { stock: -1, rentalsCount: 1 } }, { new: true });
  if (!tool) throw conflict('Out of stock — mark another rental returned or increase stock first');

  rental.status = 'active';
  rental.approvedAt = new Date();
  if (rental.type === 'rent' && rental.startDate < new Date()) {
    // Approved after the requested start: the rental period starts now.
    rental.startDate = new Date();
    rental.endDate = new Date(Date.now() + rental.days * DAY_MS);
  }
  await rental.save();

  await notify(
    rental.renter,
    'rental',
    `Your ${rental.type === 'installment' ? 'purchase' : 'rental'} was approved`,
    rental.fulfillment === 'delivery'
      ? `"${tool.name}" will be delivered to ${rental.deliveryAddress}`
      : `Collect "${tool.name}" from ${supplier.address}`,
    { rentalId: rental._id, toolId: tool._id }
  );
  push(rental);
  await respond(res, rental);
});

router.post('/:id/reject', authRequired, [body('reason').optional().isString().isLength({ max: 300 })], validate, async (req, res) => {
  const rental = await loadRental(req.params.id);
  assertSupplier(rental, req.user);
  if (rental.status !== 'requested') throw badRequest(`This request is already ${rental.status}`);
  await wallet.refundRental(rental, toolName(rental));
  rental.status = 'rejected';
  rental.rejectionReason = req.body.reason || '';
  await rental.save();
  const refunded = rental.payment.status === 'refunded' ? ' Your payment was refunded.' : '';
  await notify(rental.renter, 'rental', 'Rental request declined', `${rental.rejectionReason || `"${toolName(rental)}" isn't available`}.${refunded}`, {
    rentalId: rental._id
  });
  push(rental);
  await respond(res, rental);
});

router.post('/:id/cancel', authRequired, async (req, res) => {
  const rental = await loadRental(req.params.id);
  assertRenter(rental, req.user);
  if (rental.status !== 'requested') throw badRequest('Only pending requests can be cancelled');
  await wallet.refundRental(rental, toolName(rental));
  rental.status = 'cancelled';
  await rental.save();
  await notify(rental.supplier, 'rental', 'Request cancelled', `${req.user.name} cancelled their request for "${toolName(rental)}"`, {
    rentalId: rental._id
  });
  push(rental);
  await respond(res, rental);
});

// The tool is back. A late return costs one day's rate per day, taken from
// the deposit; the supplier is paid and the rest of the deposit refunded.
router.post('/:id/return', authRequired, async (req, res) => {
  const rental = await loadRental(req.params.id);
  assertSupplier(rental, req.user);
  if (rental.status !== 'active' || rental.type !== 'rent') throw badRequest('Only active rentals can be marked returned');

  rental.returnedAt = new Date();
  rental.lateDays = lateDaysAt(rental, rental.returnedAt);
  rental.lateFee = Math.min(rental.lateDays * rental.dailyRate, rental.deposit);
  await wallet.settleRental(rental, toolName(rental));
  rental.status = 'returned';
  await rental.save();
  await Tool.updateOne({ _id: rental.tool._id }, { $inc: { stock: 1 } });

  const late = rental.lateFee > 0 ? ` A late fee of ${rental.lateFee} (${rental.lateDays} day${rental.lateDays === 1 ? '' : 's'}) was taken from your deposit.` : '';
  await notify(rental.renter, 'rental', 'Rental returned', `Thanks for renting "${toolName(rental)}".${late} Leave a review?`, {
    rentalId: rental._id,
    toolId: rental.tool._id
  });
  push(rental);
  await respond(res, rental);
});

async function installmentPaid(rental) {
  rental.monthsPaid += 1;
  if (rental.monthsPaid >= rental.monthsTotal) {
    rental.status = 'completed';
    rental.payment.status = rental.payment.method === 'wallet' ? 'released' : 'cash_paid';
    rental.payment.settledAt = new Date();
  }
  await rental.save();
  push(rental);
}

function assertActivePlan(rental) {
  if (rental.type !== 'installment' || rental.status !== 'active') throw badRequest('This is not an active installment plan');
}

// Buyer pays this month's installment from their wallet.
router.post('/:id/pay-installment', authRequired, async (req, res) => {
  const rental = await loadRental(req.params.id);
  assertRenter(rental, req.user);
  assertActivePlan(rental);
  await wallet.payInstallment(rental, toolName(rental));
  rental.payment.method = 'wallet';
  await installmentPaid(rental);
  await notify(
    rental.supplier,
    'rental',
    'Installment received',
    `${req.user.name} paid month ${rental.monthsPaid} of ${rental.monthsTotal} for "${toolName(rental)}"`,
    { rentalId: rental._id }
  );
  await respond(res, rental);
});

// Supplier records a month paid in cash. `all: true` settles the whole plan.
router.post('/:id/record-installment', authRequired, [body('all').optional().isBoolean().toBoolean()], validate, async (req, res) => {
  const rental = await loadRental(req.params.id);
  assertSupplier(rental, req.user);
  assertActivePlan(rental);
  if (req.body.all) rental.monthsPaid = rental.monthsTotal - 1;
  await installmentPaid(rental);
  const done = rental.status === 'completed';
  await notify(
    rental.renter,
    'rental',
    done ? 'Purchase completed' : 'Installment recorded',
    done ? `"${toolName(rental)}" is fully paid. Enjoy!` : `Month ${rental.monthsPaid} of ${rental.monthsTotal} for "${toolName(rental)}" was recorded as paid.`,
    { rentalId: rental._id }
  );
  await respond(res, rental);
});

router.post(
  '/:id/review',
  authRequired,
  [
    body('rating').isInt({ min: 1, max: 5 }).withMessage('Rating must be 1–5 stars').toInt(),
    body('review').optional().isString().isLength({ max: 1000 })
  ],
  validate,
  async (req, res) => {
    const rental = await loadRental(req.params.id);
    assertRenter(rental, req.user);
    if (!['returned', 'completed'].includes(rental.status)) throw badRequest('You can review a tool after the rental ends');
    if (rental.rating) throw conflict('You already reviewed this rental');
    rental.rating = req.body.rating;
    rental.review = (req.body.review || '').trim();
    await rental.save();

    const tool = await Tool.findById(rental.tool._id);
    if (tool) {
      const total = tool.rating * tool.ratingCount + rental.rating;
      tool.ratingCount += 1;
      tool.rating = Math.round((total / tool.ratingCount) * 100) / 100;
      await tool.save();
      await notify(tool.supplier, 'review', `New ${rental.rating}★ tool review`, rental.review || tool.name, { toolId: tool._id });
    }
    await respond(res, rental);
  }
);

module.exports = router;
