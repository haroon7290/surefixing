// Rental request lifecycle. Suppliers approve/reject/return; renters cancel
// pending requests and review finished rentals. See models/Rental.js.
const express = require('express');
const mongoose = require('mongoose');
const { body } = require('express-validator');
const Rental = require('../models/Rental');
const Tool = require('../models/Tool');
const { authRequired } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { notify } = require('../utils/notify');
const realtime = require('../utils/realtime');
const { serializeRental, supplierRentalQuery, populateRental, listRentals, DAY_MS } = require('../services/rentals');
const { paginate, setTotal, sameId, badRequest, forbidden, notFound, conflict } = require('../utils/http');

const router = express.Router();

async function loadRental(id) {
  if (!mongoose.isValidObjectId(id)) throw notFound('Rental not found');
  const rental = await Rental.findById(id).populate('tool');
  if (!rental) throw notFound('Rental not found');
  return rental;
}

function supplierOf(rental) {
  return rental.supplier || rental.tool?.supplier || null;
}

function assertSupplier(rental, user) {
  if (user.role === 'admin') return;
  if (!sameId(supplierOf(rental), user._id)) throw forbidden('Only the tool owner can do this');
}

async function pushUpdate(rental, title, body) {
  await notify(rental.renter, 'rental', title, body, { rentalId: rental._id, toolId: rental.tool?._id || rental.tool });
  realtime.emit(rental.renter, 'rental:update', { rentalId: rental._id, status: rental.status });
  const supplier = supplierOf(rental);
  if (supplier) realtime.emit(supplier, 'rental:update', { rentalId: rental._id, status: rental.status });
}

async function respond(res, rental) {
  const fresh = await populateRental(Rental.findById(rental._id));
  res.json(serializeRental(fresh));
}

// ?as=renter (default) | supplier   ?status=requested,active
router.get('/', authRequired, async (req, res) => {
  const filter = req.query.as === 'supplier' ? await supplierRentalQuery(req.user._id) : { renter: req.user._id };
  if (req.query.status) filter.status = { $in: String(req.query.status).split(',') };
  const { limit, skip } = paginate(req, { defaultLimit: 50 });
  const { items, total } = await listRentals(filter, { skip, limit });
  setTotal(res, total);
  res.json(items);
});

router.get('/:id', authRequired, async (req, res) => {
  const rental = await loadRental(req.params.id);
  const allowed =
    sameId(rental.renter, req.user._id) || sameId(supplierOf(rental), req.user._id) || req.user.role === 'admin';
  if (!allowed) throw forbidden('Not your rental');
  await respond(res, rental);
});

router.post('/:id/approve', authRequired, async (req, res) => {
  const rental = await loadRental(req.params.id);
  assertSupplier(rental, req.user);
  if (rental.status !== 'requested') throw badRequest(`This request is already ${rental.status}`);

  // Reserve one unit atomically so two approvals can't oversell the last one.
  const tool = await Tool.findOneAndUpdate(
    { _id: rental.tool._id, stock: { $gt: 0 } },
    { $inc: { stock: -1, rentalsCount: 1 } },
    { new: true }
  );
  if (!tool) throw conflict('Out of stock — mark another rental returned or increase stock first');

  rental.status = 'active';
  rental.approvedAt = new Date();
  if (!rental.supplier) rental.supplier = tool.supplier;
  if (rental.type === 'rent' && rental.startDate < new Date()) {
    // Approved after the requested start: the rental period starts now.
    rental.startDate = new Date();
    rental.endDate = new Date(Date.now() + rental.days * DAY_MS);
  }
  await rental.save();
  const what = rental.type === 'installment' ? 'purchase' : 'rental';
  await pushUpdate(rental, `Your ${what} was approved`, `"${tool.name}" is ready${rental.fulfillment === 'delivery' ? ' for delivery' : ' for pickup'}`);
  await respond(res, rental);
});

router.post(
  '/:id/reject',
  authRequired,
  [body('reason').optional().isString().isLength({ max: 300 })],
  validate,
  async (req, res) => {
    const rental = await loadRental(req.params.id);
    assertSupplier(rental, req.user);
    if (rental.status !== 'requested') throw badRequest(`This request is already ${rental.status}`);
    rental.status = 'rejected';
    rental.rejectionReason = req.body.reason || '';
    await rental.save();
    await pushUpdate(rental, 'Rental request declined', rental.rejectionReason || `"${rental.tool.name}" request was declined`);
    await respond(res, rental);
  }
);

router.post('/:id/cancel', authRequired, async (req, res) => {
  const rental = await loadRental(req.params.id);
  if (!sameId(rental.renter, req.user._id)) throw forbidden('Not your rental');
  if (rental.status !== 'requested') throw badRequest('Only pending requests can be cancelled');
  rental.status = 'cancelled';
  await rental.save();
  const supplier = supplierOf(rental);
  await notify(supplier, 'rental', 'Request cancelled', `${req.user.name} cancelled their request for "${rental.tool.name}"`, {
    rentalId: rental._id
  });
  realtime.emit(supplier, 'rental:update', { rentalId: rental._id, status: rental.status });
  await respond(res, rental);
});

router.post('/:id/return', authRequired, async (req, res) => {
  const rental = await loadRental(req.params.id);
  assertSupplier(rental, req.user);
  if (rental.status !== 'active' || rental.type !== 'rent') throw badRequest('Only active rentals can be marked returned');
  rental.status = 'returned';
  rental.returnedAt = new Date();
  await rental.save();
  await Tool.updateOne({ _id: rental.tool._id }, { $inc: { stock: 1 } });
  await pushUpdate(rental, 'Rental returned', `Thanks for renting "${rental.tool.name}". Leave a review?`);
  await respond(res, rental);
});

// Installment purchase fully paid / handed over.
router.post('/:id/complete', authRequired, async (req, res) => {
  const rental = await loadRental(req.params.id);
  assertSupplier(rental, req.user);
  if (rental.status !== 'active' || rental.type !== 'installment') throw badRequest('Only active installment plans can be completed');
  rental.status = 'completed';
  rental.monthsRemaining = 0;
  await rental.save();
  await pushUpdate(rental, 'Purchase completed', `"${rental.tool.name}" is fully paid. Enjoy!`);
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
    if (!sameId(rental.renter, req.user._id)) throw forbidden('Not your rental');
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
