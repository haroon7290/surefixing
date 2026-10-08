const express = require('express');
const Tool = require('../models/Tool');
const Rental = require('../models/Rental');
const { authRequired, requireRole } = require('../middleware/auth');
const { notify } = require('../utils/notify');
const realtime = require('../utils/realtime');

const router = express.Router();

router.get('/', authRequired, async (req, res) => {
  const { mine } = req.query;
  const q = {};
  if (req.user.role === 'supplier' && mine === '1') q.supplier = req.user._id;
  const tools = await Tool.find(q).populate('supplier', 'name email');
  res.json(tools);
});

router.post('/', authRequired, requireRole('supplier'), async (req, res) => {
  const tool = await Tool.create({ ...req.body, supplier: req.user._id });
  res.status(201).json(tool);
});

router.patch('/:id', authRequired, requireRole('supplier'), async (req, res) => {
  const tool = await Tool.findById(req.params.id);
  if (!tool) return res.status(404).json({ error: 'Not found' });
  if (String(tool.supplier) !== String(req.user._id)) return res.status(403).json({ error: 'Not your tool' });
  Object.assign(tool, req.body);
  await tool.save();
  res.json(tool);
});

router.delete('/:id', authRequired, requireRole('supplier'), async (req, res) => {
  const tool = await Tool.findById(req.params.id);
  if (!tool) return res.status(404).json({ error: 'Not found' });
  if (String(tool.supplier) !== String(req.user._id)) return res.status(403).json({ error: 'Not your tool' });
  await tool.deleteOne();
  res.json({ ok: true });
});

router.post('/:id/rent', authRequired, async (req, res) => {
  const tool = await Tool.findById(req.params.id);
  if (!tool || !tool.available || tool.stock <= 0) {
    return res.status(404).json({ error: 'Tool unavailable' });
  }
  if (String(tool.supplier) === String(req.user._id)) {
    return res.status(400).json({ error: "You can't rent your own tool" });
  }
  const { days } = req.body;
  if (!days || days < 1) return res.status(400).json({ error: 'days required' });
  const rental = await Rental.create({
    tool: tool._id,
    renter: req.user._id,
    type: 'rent',
    days,
    startDate: new Date(),
    endDate: new Date(Date.now() + days * 24 * 3600 * 1000),
    totalCost: days * tool.rentPricePerDay
  });
  tool.stock = Math.max(0, tool.stock - 1);
  if (tool.stock === 0) tool.available = false;
  await tool.save();

  await notify(
    tool.supplier,
    'rental',
    'Tool rented',
    `${req.user.name} rented "${tool.name}" for ${days}d`,
    { toolId: tool._id, rentalId: rental._id }
  );
  realtime.emit(tool.supplier, 'tool:rented', {
    toolId: tool._id,
    toolName: tool.name,
    renterName: req.user.name,
    days,
    totalCost: rental.totalCost
  });
  res.status(201).json(rental);
});

router.post('/:id/purchase', authRequired, async (req, res) => {
  const tool = await Tool.findById(req.params.id);
  if (!tool || !tool.available || tool.stock <= 0) {
    return res.status(404).json({ error: 'Tool unavailable' });
  }
  if (String(tool.supplier) === String(req.user._id)) {
    return res.status(400).json({ error: "You can't buy your own tool" });
  }
  if (!tool.installmentMonths) return res.status(400).json({ error: 'Tool not on installment plan' });
  const rental = await Rental.create({
    tool: tool._id,
    renter: req.user._id,
    type: 'installment',
    totalCost: tool.purchasePrice,
    monthsRemaining: tool.installmentMonths,
    startDate: new Date()
  });
  tool.stock = Math.max(0, tool.stock - 1);
  if (tool.stock === 0) tool.available = false;
  await tool.save();

  await notify(
    tool.supplier,
    'rental',
    'Tool purchased',
    `${req.user.name} bought "${tool.name}" on installments`,
    { toolId: tool._id, rentalId: rental._id }
  );
  realtime.emit(tool.supplier, 'tool:purchased', {
    toolId: tool._id,
    toolName: tool.name,
    renterName: req.user.name,
    totalCost: rental.totalCost,
    months: tool.installmentMonths
  });
  res.status(201).json(rental);
});

router.get('/me/rentals', authRequired, async (req, res) => {
  const rentals = await Rental.find({ renter: req.user._id })
    .populate('tool')
    .sort({ createdAt: -1 });
  res.json(rentals);
});

// Suppliers: list rentals/purchases of the tools they own.
router.get('/me/incoming', authRequired, requireRole('supplier'), async (req, res) => {
  const ownTools = await Tool.find({ supplier: req.user._id }).select('_id');
  const ids = ownTools.map((t) => t._id);
  const rentals = await Rental.find({ tool: { $in: ids } })
    .populate('tool', 'name')
    .populate('renter', 'name email')
    .sort({ createdAt: -1 });
  res.json(rentals);
});

module.exports = router;
