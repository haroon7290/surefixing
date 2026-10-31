const { app, request, connect, disconnect, makeUser } = require('./helpers');

beforeAll(connect);
afterAll(disconnect);

// How a rented or bought tool changes hands, and customer ↔ supplier chat.
describe('pickup / delivery details and tool chat', () => {
  let supplier;
  let renter;
  let stranger;
  let tool;

  beforeAll(async () => {
    supplier = await makeUser('supplier', { register: { city: 'Lahore', phone: '042-111' } });
    renter = await makeUser('client', { register: { phone: '0300-222' } });
    stranger = await makeUser('client');
    const res = await supplier
      .api('post', '/api/tools')
      .send({ name: 'Hammer drill', rentPricePerDay: 500, stock: 3, purchasePrice: 20000, installmentMonths: 4, installmentMonthly: 5000 });
    tool = res.body;
  });

  test('address is editable and private: shown to the owner, never on public profiles', async () => {
    await supplier.api('patch', '/api/users/me').send({ address: 'x'.repeat(301) }).expect(400);
    const me = await supplier.api('patch', '/api/users/me').send({ address: 'Shop 12, Hall Road, Lahore' });
    expect(me.body.address).toBe('Shop 12, Hall Road, Lahore');
    const pub = await request(app).get(`/api/users/${supplier.id}`).expect(200);
    expect(pub.body.address).toBeUndefined();
    await supplier.api('patch', '/api/users/me').send({ address: '' }).expect(200); // for the next test
  });

  test('a supplier needs a pickup address before approving a pickup', async () => {
    const r = await renter.api('post', `/api/tools/${tool._id}/rent`).send({ days: 2 });
    expect(r.status).toBe(201);
    expect(r.body.handover).toMatchObject({ method: 'pickup', revealed: false });

    const blocked = await supplier.api('post', `/api/rentals/${r.body._id}/approve`);
    expect(blocked.status).toBe(400);
    expect(blocked.body.error).toMatch(/pickup address/i);

    await supplier.api('patch', '/api/users/me').send({ address: 'Shop 12, Hall Road, Lahore' }).expect(200);
    await supplier.api('post', `/api/rentals/${r.body._id}/approve`).expect(200);
  });

  test('contact details and the pickup address appear only after approval', async () => {
    const r = await renter.api('post', `/api/tools/${tool._id}/rent`).send({ days: 1 });
    let mine = await renter.api('get', `/api/rentals/${r.body._id}`);
    expect(mine.body.supplier.phone).toBeUndefined();
    expect(mine.body.supplier.address).toBeUndefined();
    expect(mine.body.handover).toMatchObject({ method: 'pickup', address: '', city: 'Lahore', revealed: false });
    const incoming = await supplier.api('get', `/api/rentals/${r.body._id}`);
    expect(incoming.body.renter.phone).toBeUndefined();

    await supplier.api('post', `/api/rentals/${r.body._id}/approve`).expect(200);
    mine = await renter.api('get', `/api/rentals/${r.body._id}`);
    expect(mine.body.supplier.phone).toBe('042-111');
    expect(mine.body.handover).toMatchObject({ method: 'pickup', address: 'Shop 12, Hall Road, Lahore', revealed: true });
    const after = await supplier.api('get', `/api/rentals/${r.body._id}`);
    expect(after.body.renter.phone).toBe('0300-222');
  });

  test('delivery needs an address; the profile address is the default', async () => {
    const none = await stranger.api('post', `/api/tools/${tool._id}/rent`).send({ days: 1, fulfillment: 'delivery' });
    expect(none.status).toBe(400);
    expect(none.body.error).toMatch(/address/i);

    const given = await stranger
      .api('post', `/api/tools/${tool._id}/rent`)
      .send({ days: 1, fulfillment: 'delivery', deliveryAddress: 'House 5, Gulberg' });
    expect(given.body.handover).toMatchObject({ method: 'delivery', address: 'House 5, Gulberg' });

    await renter.api('patch', '/api/users/me').send({ address: 'Flat 3, DHA' }).expect(200);
    const dflt = await renter.api('post', `/api/tools/${tool._id}/rent`).send({ days: 1, fulfillment: 'delivery' });
    expect(dflt.body.deliveryAddress).toBe('Flat 3, DHA');
    // The supplier sees where to deliver even before approving.
    const incoming = await supplier.api('get', `/api/rentals/${dflt.body._id}`);
    expect(incoming.body.handover.address).toBe('Flat 3, DHA');
  });

  test('installment purchases choose pickup or delivery too', async () => {
    const p = await renter.api('post', `/api/tools/${tool._id}/purchase`).send({ fulfillment: 'delivery', deliveryAddress: 'Office 2, Blue Area' });
    expect(p.status).toBe(201);
    expect(p.body).toMatchObject({ type: 'installment', fulfillment: 'delivery', deliveryAddress: 'Office 2, Blue Area' });
  });

  test('customer and supplier chat about a tool; strangers are not reachable', async () => {
    const hi = await stranger.api('post', `/api/messages/tool/${tool._id}`).send({ text: 'Does it come with bits?' });
    expect(hi.status).toBe(201);
    expect(hi.body).toMatchObject({ tool: tool._id, job: null, thread: `tool:${tool._id}`, recipient: supplier.id });

    // Supplier must say who they reply to, and only to people who asked or rented.
    await supplier.api('post', `/api/messages/tool/${tool._id}`).send({ text: 'Yes' }).expect(400);
    const outsider = await makeUser('client');
    await supplier.api('post', `/api/messages/tool/${tool._id}`).send({ text: 'Hi', to: outsider.id }).expect(403);
    await supplier.api('post', `/api/messages/tool/${tool._id}`).send({ text: 'Yes, 5 bits included.', to: stranger.id }).expect(201);
    // A renter who never wrote can still be messaged about their rental.
    await supplier.api('post', `/api/messages/tool/${tool._id}`).send({ text: 'Ready for pickup', to: renter.id }).expect(201);

    const thread = await stranger.api('get', `/api/messages/tool/${tool._id}`);
    expect(thread.body.map((m) => m.text)).toEqual(['Does it come with bits?', 'Yes, 5 bits included.']);

    const inbox = await supplier.api('get', '/api/messages');
    const rows = inbox.body.filter((c) => c.kind === 'tool');
    expect(rows).toHaveLength(2);
    expect(rows[0]).toMatchObject({ toolId: tool._id, toolName: 'Hammer drill' });

    const unread = await renter.api('get', '/api/messages/unread-count');
    expect(unread.body.count).toBe(1);
    await renter.api('get', `/api/messages/tool/${tool._id}`).expect(200);
    expect((await renter.api('get', '/api/messages/unread-count')).body.count).toBe(0);
  });
});
