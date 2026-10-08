const Rental = require('../models/Rental');
const Tool = require('../models/Tool');

const DAY_MS = 24 * 3600 * 1000;

// Adds computed fields the app shows (overdue flag, days left).
function serializeRental(r) {
  const json = typeof r.toJSON === 'function' ? r.toJSON() : r;
  const end = json.endDate ? new Date(json.endDate).getTime() : null;
  const active = json.status === 'active' && json.type === 'rent';
  json.overdue = Boolean(active && end && end < Date.now());
  json.daysLeft = active && end ? Math.ceil((end - Date.now()) / DAY_MS) : null;
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
    .populate('renter', 'name avatar city rating phone')
    .populate('supplier', 'name avatar city phone');
}

async function listRentals(filter, { skip = 0, limit = 50 } = {}) {
  const [items, total] = await Promise.all([
    populateRental(Rental.find(filter)).sort({ createdAt: -1 }).skip(skip).limit(limit),
    Rental.countDocuments(filter)
  ]);
  return { items: items.map(serializeRental), total };
}

module.exports = { serializeRental, supplierRentalQuery, populateRental, listRentals, DAY_MS };
