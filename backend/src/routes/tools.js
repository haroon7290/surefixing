const express = require('express');
const mongoose = require('mongoose');
const { body } = require('express-validator');
const Tool = require('../models/Tool');
const Rental = require('../models/Rental');
const { authRequired, optionalAuth, requireRole } = require('../middleware/auth');
const { validate, discardUploads } = require('../middleware/validate');
const upload = require('../middleware/upload');
const { notify } = require('../utils/notify');
const realtime = require('../utils/realtime');
const { removeUpload } = require('../utils/files');
const wallet = require('../services/wallet');
const { toolCategoryKeys, TOOL_CONDITIONS, PAYMENT_METHODS } = require('../config/catalog');
const { serializeRental, DAY_MS } = require('../services/rentals');
const { nearbySearch, readNearby } = require('../services/nearby');
const { latLng, distanceKm, round1 } = require('../utils/geo');
const { escapeRegex, paginate, setTotal, sameId, badRequest, forbidden, notFound } = require('../utils/http');

const router = express.Router();
const MAX_IMAGES = 6;

const toolValidators = (optional) => {
  const f = (name) => (optional ? body(name).optional() : body(name));
  return [
    f('name').trim().isLength({ min: 2, max: 100 }).withMessage('Tool name must be 2–100 characters'),
    body('description').optional().isString().isLength({ max: 2000 }),
    body('category').optional({ values: 'falsy' }).isIn(toolCategoryKeys).withMessage('Unknown tool category'),
    body('condition').optional({ values: 'falsy' }).isIn(TOOL_CONDITIONS).withMessage('Unknown condition'),
    body('city').optional().trim().isLength({ max: 60 }),
    body('rentPricePerDay').optional().isFloat({ min: 0, max: 1000000 }).withMessage('Rent price must be a positive number').toFloat(),
    body('deposit').optional().isFloat({ min: 0, max: 1000000 }).toFloat(),
    body('purchasePrice').optional().isFloat({ min: 0, max: 10000000 }).toFloat(),
    body('installmentMonths').optional().isInt({ min: 0, max: 60 }).withMessage('Installment months must be 0–60').toInt(),
    body('installmentMonthly').optional().isFloat({ min: 0, max: 10000000 }).toFloat(),
    body('stock').optional().isInt({ min: 0, max: 10000 }).withMessage('Stock must be 0 or more').toInt(),
    body('available').optional().isBoolean().toBoolean()
  ];
};

// Whitelists supplier-editable fields. Text fields may be cleared with "".
function pick(src) {
  const out = {};
  for (const key of Tool.EDITABLE) {
    const v = src[key];
    if (v === undefined || (v === '' && !['description', 'city'].includes(key))) continue;
    out[key] = v;
  }
  return out;
}

async function loadTool(id) {
  if (!mongoose.isValidObjectId(id)) throw notFound('Tool not found');
  const tool = await Tool.findById(id);
  if (!tool) throw notFound('Tool not found');
  return tool;
}

// --------------------------------------------------------------- browse

// ?q= ?category= ?city= ?minPrice= ?maxPrice= ?available=1 ?installment=1
// ?sort=newest|price_asc|price_desc|rating|popular|distance ?mine=1 (supplier)
// ?lat=&lng= (distances in the results) ?radius=5 (only within 5 km)
router.get('/', optionalAuth, async (req, res) => {
  const { mine, q: text, category, city, minPrice, maxPrice, available, installment, sort } = req.query;
  const q = {};
  if (req.user?.role === 'supplier' && mine === '1') q.supplier = req.user._id;
  else q.available = true;
  if (text) {
    const rx = new RegExp(escapeRegex(String(text).trim()), 'i');
    q.$or = [{ name: rx }, { description: rx }, { category: rx }];
  }
  if (category) q.category = String(category);
  if (city) q.city = new RegExp(`^${escapeRegex(String(city).trim())}$`, 'i');
  if (minPrice || maxPrice) {
    q.rentPricePerDay = {};
    if (minPrice) q.rentPricePerDay.$gte = Number(minPrice) || 0;
    if (maxPrice) q.rentPricePerDay.$lte = Number(maxPrice) || 0;
  }
  if (available === '1') q.stock = { $gt: 0 };
  if (installment === '1') q.installmentMonths = { $gt: 0 };

  const sorts = {
    newest: { createdAt: -1 },
    price_asc: { rentPricePerDay: 1 },
    price_desc: { rentPricePerDay: -1 },
    rating: { rating: -1, ratingCount: -1 },
    popular: { rentalsCount: -1, rating: -1 }
  };
  const { limit, skip } = paginate(req, { defaultLimit: 50 });
  const nearby = mine === '1' ? null : readNearby(req.query);
  if (nearby) {
    const { items, total } = await nearbySearch(Tool, { ...nearby, filter: q, sort: sorts[sort] || sorts.newest, skip, limit });
    await Tool.populate(
      items.map((i) => i.doc),
      { path: 'supplier', select: 'name avatar city kycStatus' }
    );
    setTotal(res, total);
    return res.json(items.map(({ doc, km }) => ({ ...doc.toJSON(), distanceKm: km })));
  }
  const [tools, total] = await Promise.all([
    Tool.find(q).populate('supplier', 'name avatar city kycStatus').sort(sorts[sort] || sorts.newest).skip(skip).limit(limit),
    Tool.countDocuments(q)
  ]);
  setTotal(res, total);
  res.json(tools);
});

router.get('/:id', optionalAuth, async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw notFound('Tool not found');
  const tool = await Tool.findById(req.params.id).populate('supplier', 'name avatar city rating createdAt kycStatus');
  if (!tool) throw notFound('Tool not found');
  const from = readNearby(req.query, req.user && latLng(req.user.geo));
  const reviews = await Rental.find({ tool: tool._id, rating: { $ne: null } })
    .sort({ updatedAt: -1 })
    .limit(20)
    .populate('renter', 'name avatar');
  res.json({
    ...tool.toJSON(),
    distanceKm: from ? round1(distanceKm(from.near, latLng(tool.geo))) : null,
    reviews: reviews.map((r) => ({
      id: r._id,
      rating: r.rating,
      review: r.review,
      date: r.updatedAt,
      renterName: r.renter?.name || 'Customer',
      renterAvatar: r.renter?.avatar || ''
    }))
  });
});

// --------------------------------------------------------- supplier CRUD

router.post('/', authRequired, requireRole('supplier'), upload.array('images', 4), toolValidators(false), validate, async (req, res) => {
  const tool = await Tool.create({
    ...pick(req.body),
    city: req.body.city || req.user.city || '',
    // Tools are at the supplier's shop.
    geo: req.user.geo || undefined,
    area: req.user.area || '',
    images: (req.files || []).map((f) => f.filename),
    supplier: req.user._id
  });
  res.status(201).json(tool);
});

// Multipart or JSON. New photos in "images" are appended; `removeImages`
// (JSON array or comma list of filenames) deletes existing ones.
router.patch('/:id', authRequired, requireRole('supplier'), upload.array('images', 4), toolValidators(true), validate, async (req, res) => {
  const tool = await loadTool(req.params.id);
  if (!sameId(tool.supplier, req.user._id)) {
    discardUploads(req);
    throw forbidden('Not your tool');
  }
  Object.assign(tool, pick(req.body));

  let remove = req.body.removeImages || [];
  if (typeof remove === 'string') {
    try {
      remove = JSON.parse(remove);
    } catch (_e) {
      remove = remove.split(',');
    }
  }
  const removeSet = new Set((Array.isArray(remove) ? remove : []).map((s) => String(s).trim()));
  tool.images.filter((img) => removeSet.has(img)).forEach(removeUpload);
  const kept = tool.images.filter((img) => !removeSet.has(img));
  const added = (req.files || []).map((f) => f.filename);
  added.slice(Math.max(0, MAX_IMAGES - kept.length)).forEach(removeUpload);
  tool.images = [...kept, ...added].slice(0, MAX_IMAGES);

  await tool.save();
  res.json(tool);
});

router.delete('/:id', authRequired, requireRole('supplier', 'admin'), async (req, res) => {
  const tool = await loadTool(req.params.id);
  if (req.user.role !== 'admin' && !sameId(tool.supplier, req.user._id)) throw forbidden('Not your tool');
  const active = await Rental.countDocuments({ tool: tool._id, status: 'active' });
  if (active) throw badRequest('This tool is out with a customer. Mark it returned first, or unlist the tool instead.');

  const pending = await Rental.find({ tool: tool._id, status: 'requested' });
  for (const r of pending) {
    await wallet.refundRental(r, tool.name);
    r.status = 'cancelled';
    r.rejectionReason = 'The supplier removed this tool';
    await r.save();
    await notify(r.renter, 'rental', 'Rental request cancelled', `"${tool.name}" is no longer available.`, { rentalId: r._id });
  }
  tool.images.forEach(removeUpload);
  await tool.deleteOne();
  res.json({ ok: true });
});

// ------------------------------------------------------ rent / purchase

const requestValidators = [
  body('fulfillment').optional().isIn(['pickup', 'delivery']).withMessage('Choose pickup or delivery'),
  body('deliveryAddress').optional().isString().trim().isLength({ max: 300 }).withMessage('Address is too long (max 300 characters)'),
  body('note').optional().isString().isLength({ max: 500 })
];

// Pickup (from the supplier) or delivery (to an address the customer gives;
// their saved profile address is the default).
function handover(req) {
  const fulfillment = req.body?.fulfillment === 'delivery' ? 'delivery' : 'pickup';
  if (fulfillment === 'pickup') return { fulfillment, deliveryAddress: '' };
  const deliveryAddress = String(req.body?.deliveryAddress || req.user.address || '').trim();
  if (!deliveryAddress) throw badRequest('Enter the address to deliver to');
  return { fulfillment, deliveryAddress };
}

async function loadRentable(req, verb) {
  const tool = await loadTool(req.params.id);
  if (!tool.available || tool.stock <= 0) throw badRequest('This tool is currently unavailable');
  if (sameId(tool.supplier, req.user._id)) throw badRequest(`You can't ${verb} your own tool`);
  return tool;
}

function announce(tool, rental, user, title, text) {
  realtime.emit(tool.supplier, 'rental:new', { rentalId: rental._id, toolId: tool._id, toolName: tool.name, renterName: user.name });
  return notify(tool.supplier, 'rental', title, text, { toolId: tool._id, rentalId: rental._id });
}

// Rent for a date range. Paying by wallet holds the rental cost and the
// deposit until the tool is returned (or refunds them if declined).
router.post(
  '/:id/rent',
  authRequired,
  [
    body('days').optional().isInt({ min: 1, max: 90 }).withMessage('Rental length must be 1–90 days').toInt(),
    body('startDate').optional().isISO8601().withMessage('Invalid start date'),
    body('endDate').optional().isISO8601().withMessage('Invalid end date'),
    body('paymentMethod').optional().isIn(PAYMENT_METHODS).withMessage('Choose wallet or cash'),
    ...requestValidators
  ],
  validate,
  async (req, res) => {
    const tool = await loadRentable(req, 'rent');

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const start = req.body.startDate ? new Date(req.body.startDate) : new Date();
    if (start.getTime() < today.getTime()) throw badRequest('Start date cannot be in the past');
    let days = req.body.days;
    if (req.body.endDate) {
      days = Math.ceil((new Date(req.body.endDate).getTime() - start.getTime()) / DAY_MS);
      if (days < 1) throw badRequest('End date must be after the start date');
      if (days > 90) throw badRequest('Rentals can be at most 90 days');
    }
    if (!days) throw badRequest('Choose how many days you need the tool');

    const rental = new Rental({
      tool: tool._id,
      renter: req.user._id,
      supplier: tool.supplier,
      type: 'rent',
      days,
      startDate: start,
      endDate: new Date(start.getTime() + days * DAY_MS),
      dailyRate: tool.rentPricePerDay,
      totalCost: Math.round(days * tool.rentPricePerDay * 100) / 100,
      deposit: tool.deposit || 0,
      ...handover(req),
      note: req.body.note || '',
      status: 'requested'
    });
    await wallet.holdForRental(rental, req.body.paymentMethod || 'cash', tool.name); // 402 if the wallet is short
    await rental.save();

    await announce(tool, rental, req.user, 'New rental request', `${req.user.name} wants "${tool.name}" for ${days} day${days === 1 ? '' : 's'}`);
    res.status(201).json(serializeRental(rental));
  }
);

// Buy on a monthly installment plan. Each month is paid from the wallet or
// recorded by the supplier when paid in cash.
router.post('/:id/purchase', authRequired, requestValidators, validate, async (req, res) => {
  const tool = await loadRentable(req, 'buy');
  if (!tool.installmentMonths) throw badRequest('This tool is not offered on installments');

  const rental = await Rental.create({
    tool: tool._id,
    renter: req.user._id,
    supplier: tool.supplier,
    type: 'installment',
    totalCost: tool.purchasePrice,
    monthsTotal: tool.installmentMonths,
    monthsPaid: 0,
    monthlyAmount: tool.installmentMonthly || Math.ceil(tool.purchasePrice / tool.installmentMonths),
    payment: { method: 'cash', status: 'none', amount: tool.purchasePrice, net: tool.purchasePrice },
    startDate: new Date(),
    ...handover(req),
    note: req.body.note || '',
    status: 'requested'
  });
  await announce(tool, rental, req.user, 'New purchase request', `${req.user.name} wants to buy "${tool.name}" on installments`);
  res.status(201).json(serializeRental(rental));
});

module.exports = router;
