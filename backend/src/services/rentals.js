const Rental = require('../models/Rental');

const DAY_MS = 24 * 3600 * 1000;
const HOUR_MS = 3600 * 1000;

// Once a supplier approves, both sides need each other's phone and the
// handover address; before that (or after a decline) they stay private.
const APPROVED = ['active', 'returned', 'completed'];

// Populated users are plain objects after toJSON; bare ids are ObjectIds.
const isPopulated = (v) => Boolean(v) && Object.getPrototypeOf(v) === Object.prototype;

function withoutContact(user) {
  if (!isPopulated(user)) return user;
  const { phone, address, email, ...rest } = user;
  return rest;
}

// Days past the due date (0 when on time or not a rental).
function lateDaysAt(rental, when = new Date()) {
  if (rental.type !== 'rent' || !rental.endDate) return 0;
  const late = new Date(when).getTime() - new Date(rental.endDate).getTime();
  return late > 0 ? Math.ceil(late / DAY_MS) : 0;
}

// Days actually used when a rental comes back at [when]: at least one, and
// part of a day counts as a day after an hour's grace (back 25 minutes past
// one full day is still one day). On time or late: all the booked days.
function usedDaysAt(rental, when = new Date()) {
  if (rental.type !== 'rent' || !rental.days) return 0;
  const start = new Date(rental.startDate || rental.approvedAt || when).getTime();
  const elapsed = new Date(when).getTime() - start;
  const used = Math.max(1, Math.ceil((elapsed - HOUR_MS) / DAY_MS));
  return Math.min(used, rental.days);
}

// Adds what the app shows but the database doesn't store: overdue flag, days
// left, the invoice number, and how the tool changes hands.
function serializeRental(r) {
  const json = typeof r.toJSON === 'function' ? r.toJSON() : r;
  const end = json.endDate ? new Date(json.endDate).getTime() : null;
  const active = json.status === 'active' && json.type === 'rent';
  json.overdue = Boolean(active && end && end < Date.now());
  json.daysLeft = active && end ? Math.ceil((end - Date.now()) / DAY_MS) : null;
  if (json.overdue) {
    json.lateDays = lateDaysAt(json);
    json.lateFee = Math.min(json.lateDays * (json.dailyRate || 0), json.deposit || 0);
  }
  if (json.number) json.invoiceNo = `INV-${json.number}`;

  const approved = APPROVED.includes(json.status);
  if (!approved) {
    json.renter = withoutContact(json.renter);
    json.supplier = withoutContact(json.supplier);
  }
  // For pickups the supplier's address is only revealed after approval;
  // until then just the city.
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

function populateRental(query) {
  return query
    .populate('tool', 'name images rentPricePerDay deposit purchasePrice category condition supplier city')
    .populate('renter', 'name avatar city rating phone address email')
    .populate('supplier', 'name avatar city phone address kycStatus email');
}

async function listRentals(filter, { skip = 0, limit = 50 } = {}) {
  const [items, total] = await Promise.all([
    populateRental(Rental.find(filter)).sort({ createdAt: -1 }).skip(skip).limit(limit),
    Rental.countDocuments(filter)
  ]);
  return { items: items.map(serializeRental), total };
}

module.exports = { APPROVED, DAY_MS, lateDaysAt, usedDaysAt, serializeRental, populateRental, listRentals };
