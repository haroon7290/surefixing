const { connect, disconnect, makeUser } = require('./helpers');
const Tool = require('../src/models/Tool');

beforeAll(connect);
afterAll(disconnect);

const tomorrow = () => new Date(Date.now() + 24 * 3600 * 1000).toISOString();

describe('tools & rental requests', () => {
  let supplier;
  let otherSupplier;
  let renter;
  let renter2;
  let tool;

  beforeAll(async () => {
    supplier = await makeUser('supplier', { register: { city: 'Lahore' } });
    otherSupplier = await makeUser('supplier');
    renter = await makeUser('client');
    renter2 = await makeUser('technician');
  });

  test('supplier creates a tool; server-managed fields cannot be injected', async () => {
    const res = await supplier.api('post', '/api/tools').send({
      name: 'Cordless Drill',
      category: 'power',
      rentPricePerDay: 800,
      deposit: 5000,
      purchasePrice: 30000,
      installmentMonths: 6,
      installmentMonthly: 5500,
      stock: 1,
      supplier: otherSupplier.id,
      rating: 5,
      rentalsCount: 999
    });
    expect(res.status).toBe(201);
    tool = res.body;
    expect(tool.supplier).toBe(supplier.id);
    expect(tool.rating).toBe(0);
    expect(tool.rentalsCount).toBe(0);
    expect(tool.city).toBe('Lahore');
  });

  test('validation and ownership on update', async () => {
    await supplier.api('post', '/api/tools').send({ name: 'X', rentPricePerDay: -1 }).expect(400);
    await otherSupplier.api('patch', `/api/tools/${tool._id}`).send({ name: 'Hijacked' }).expect(403);
    const patched = await supplier.api('patch', `/api/tools/${tool._id}`).send({ name: 'Bosch Drill', supplier: otherSupplier.id });
    expect(patched.status).toBe(200);
    expect(patched.body.name).toBe('Bosch Drill');
    expect(patched.body.supplier).toBe(supplier.id);
  });

  test('browse with search and filters', async () => {
    await supplier.api('post', '/api/tools').send({ name: 'Ladder 12ft', category: 'ladders', rentPricePerDay: 300 }).expect(201);
    const all = await renter.api('get', '/api/tools');
    expect(all.body.length).toBe(2);
    const search = await renter.api('get', '/api/tools?q=bosch');
    expect(search.body.map((t) => t.name)).toEqual(['Bosch Drill']);
    const cheap = await renter.api('get', '/api/tools?maxPrice=500');
    expect(cheap.body.map((t) => t.name)).toEqual(['Ladder 12ft']);
    const sorted = await renter.api('get', '/api/tools?sort=price_asc');
    expect(sorted.body[0].name).toBe('Ladder 12ft');
    const detail = await renter.api('get', `/api/tools/${tool._id}`);
    expect(detail.body.supplier.name).toBeTruthy();
    expect(detail.body.reviews).toEqual([]);
  });

  test('rent request → approve reserves stock → out of stock → return releases → review', async () => {
    await supplier.api('post', `/api/tools/${tool._id}/rent`).send({ days: 2 }).expect(400); // own tool
    await renter.api('post', `/api/tools/${tool._id}/rent`).send({}).expect(400); // no days

    const start = tomorrow();
    const end = new Date(Date.now() + 4 * 24 * 3600 * 1000).toISOString();
    const req1 = await renter.api('post', `/api/tools/${tool._id}/rent`).send({ startDate: start, endDate: end, fulfillment: 'delivery' });
    expect(req1.status).toBe(201);
    expect(req1.body).toMatchObject({ status: 'requested', days: 3, totalCost: 2400, deposit: 5000, fulfillment: 'delivery' });
    const req2 = await renter2.api('post', `/api/tools/${tool._id}/rent`).send({ days: 1 });
    expect(req2.status).toBe(201);

    // Requests don't touch stock.
    expect((await Tool.findById(tool._id)).stock).toBe(1);

    const incoming = await supplier.api('get', '/api/rentals?as=supplier&status=requested');
    expect(incoming.body).toHaveLength(2);
    expect(incoming.body[0].renter.name).toBeTruthy();

    await renter.api('post', `/api/rentals/${req1.body._id}/approve`).expect(403);
    const approved = await supplier.api('post', `/api/rentals/${req1.body._id}/approve`);
    expect(approved.status).toBe(200);
    expect(approved.body.status).toBe('active');
    expect((await Tool.findById(tool._id)).stock).toBe(0);

    // Last unit is gone: the second approval must fail atomically.
    await supplier.api('post', `/api/rentals/${req2.body._id}/approve`).expect(409);
    await renter2.api('post', `/api/tools/${tool._id}/rent`).send({ days: 1 }).expect(400);

    // Renter can't review before it is returned.
    await renter.api('post', `/api/rentals/${req1.body._id}/review`).send({ rating: 5 }).expect(400);

    const returned = await supplier.api('post', `/api/rentals/${req1.body._id}/return`);
    expect(returned.body.status).toBe('returned');
    expect((await Tool.findById(tool._id)).stock).toBe(1);

    const reviewed = await renter.api('post', `/api/rentals/${req1.body._id}/review`).send({ rating: 4, review: 'Worked well' });
    expect(reviewed.status).toBe(200);
    await renter.api('post', `/api/rentals/${req1.body._id}/review`).send({ rating: 4 }).expect(409);
    const t = await Tool.findById(tool._id);
    expect(t.rating).toBe(4);
    expect(t.ratingCount).toBe(1);
    expect(t.rentalsCount).toBe(1);

    const mine = await renter.api('get', '/api/rentals');
    expect(mine.body[0].tool.name).toBe('Bosch Drill');
  });

  test('renter cancels a pending request; supplier rejects another', async () => {
    const a = await renter.api('post', `/api/tools/${tool._id}/rent`).send({ days: 1 });
    await renter2.api('post', `/api/rentals/${a.body._id}/cancel`).expect(403);
    const cancelled = await renter.api('post', `/api/rentals/${a.body._id}/cancel`);
    expect(cancelled.body.status).toBe('cancelled');

    const b = await renter.api('post', `/api/tools/${tool._id}/purchase`);
    expect(b.status).toBe(201);
    expect(b.body).toMatchObject({ type: 'installment', monthsRemaining: 6, status: 'requested' });
    const rejected = await supplier.api('post', `/api/rentals/${b.body._id}/reject`).send({ reason: 'Sold out' });
    expect(rejected.body).toMatchObject({ status: 'rejected', rejectionReason: 'Sold out' });
  });

  test('tools with active rentals cannot be deleted; pending requests are cancelled on delete', async () => {
    const ladder = (await renter.api('get', '/api/tools?q=ladder')).body[0];
    const r = await renter.api('post', `/api/tools/${ladder._id}/rent`).send({ days: 1 });
    await supplier.api('post', `/api/rentals/${r.body._id}/approve`).expect(200);
    await supplier.api('delete', `/api/tools/${ladder._id}`).expect(400);
    await supplier.api('post', `/api/rentals/${r.body._id}/return`).expect(200);

    const pending = await renter.api('post', `/api/tools/${ladder._id}/rent`).send({ days: 1 });
    await supplier.api('delete', `/api/tools/${ladder._id}`).expect(200);
    const after = await renter.api('get', `/api/rentals/${pending.body._id}`);
    expect(after.body.status).toBe('cancelled');
  });
});
