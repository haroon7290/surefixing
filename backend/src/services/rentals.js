const Rental = require('../models/Rental');
const Tool = require('../models/Tool');

const DAY_MS = 24 * 3600 * 1000;

// Once a supplier approves, both sides need each other's phone and the
// handover address; before that (or after a decline) they stay private.
const APPROVED = ['active', 'returned', 'completed'];

// Populated users are plain objects after toJSON; bare ids are ObjectIds.
const isPopulated = (v) => Boolean(v) && Object.getPrototypeOf(v) === Object.prototype;

function withoutContact(user) {
  if (!isPopulated(user)) return user;
  const { phone, address, ...rest } = user;
  return rest;
}

// Adds computed fields the app shows (overdue flag, days left, handover).
function serializeRental(r) {
  const json = typeof r.toJSON === 'function' ? r.toJSON() : r;
  const end = json.endDate ? new Date(json.endDate).getTime() : null;
  const active = json.status === 'active' && json.type === 'rent';
  json.overdue = Boolean(active && end && end < Date.now());
  json.daysLeft = active && end ? Math.ceil((end - Date.now()) / DAY_MS) : null;

  const approved = APPROVED.includes(json.status);
  if (!approved) {
    json.renter = withoutContact(json.renter);
    json.supplier = withoutContact(json.supplier);
  }
  // Where the tool changes hands. For pickups the supplier's address is only
  // revealed after approval; until then just the city.
  const supplier = isPopulated(json.supplier) ? json.supplier : {};
  const toolCity = isPopulated(json.tool) ? json.tool.city : '';
  json.handover =
    json.fulfillment === 'delivery'
      ? { method: 'delivery', address: json.deliveryAddress || '', city: '', revealed: true }
      : {
          method: 'pickup',
          address: approved ? supplier.address || '' : '',
          city: supplier.city || toolCity || '',
          revealed: approved
        };
  return json;
}

// Rentals on tools owned by a supplier. Older rentals have no `supplier`
// field, so the match also goes through the supplier's tool ids.
async function supplierRentalQuery(supplierId) {
  const toolIds = (await Tool.find({ supplier: supplierId }).select('_id')).map((t) => t._id);
  return { $or: [{ supplier: supplierId }, { tool: { $in: toolIds } }] };
}

function populateRental(query) {
  return query
    .populate('tool', 'name image images rentPricePerDay deposit category supplier city')
    .populate('renter', 'name avatar city rating phone address')
    .populate('supplier', 'name avatar city phone address kycStatus');
}

async function listRentals(filter, { skip = 0, limit = 50 } = {}) {
  const [items, total] = await Promise.all([
    populateRental(Rental.find(filter)).sort({ createdAt: -1 }).skip(skip).limit(limit),
    Rental.countDocuments(filter)
  ]);
  return { items: items.map(serializeRental), total };
}

module.exports = { APPROVED, serializeRental, supplierRentalQuery, populateRental, listRentals, DAY_MS };
