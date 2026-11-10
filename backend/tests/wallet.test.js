const { connect, disconnect, makeUser } = require('./helpers');
const User = require('../src/models/User');
const Rental = require('../src/models/Rental');
const Tool = require('../src/models/Tool');
const Transaction = require('../src/models/Transaction');

beforeAll(connect);
afterAll(disconnect);

const balance = async (user) => (await User.findById(user.id)).walletBalance;
const DAY = 24 * 3600 * 1000;

describe('wallet, rentals in escrow and installments', () => {
  let supplier;
  let renter;
  let tool;

  beforeAll(async () => {
    supplier = await makeUser('supplier', { profile: { address: 'Shop 1, Hall Road, Lahore' } });
    renter = await makeUser('client');
    tool = (
      await supplier.api('post', '/api/tools').send({
        name: 'Pressure washer',
        rentPricePerDay: 1000,
        deposit: 3000,
        stock: 5,
        purchasePrice: 12000,
        installmentMonths: 3,
        installmentMonthly: 4000
      })
    ).body;
  });

  test('top up and withdraw keep an exact ledger and never overdraw', async () => {
    await renter.api('post', '/api/wallet/topup').send({ amount: 50 }).expect(400);
    await renter.api('post', '/api/wallet/topup').send({ amount: 5000000 }).expect(400);
    expect((await renter.api('post', '/api/wallet/topup').send({ amount: 20000 })).body.balance).toBe(20000);

    const over = await renter.api('post', '/api/wallet/withdraw').send({ amount: 25000 });
    expect(over.status).toBe(402);
    expect(over.body.code).toBe('insufficient_funds');
    expect((await renter.api('post', '/api/wallet/withdraw').send({ amount: 5000 })).body.balance).toBe(15000);

    const history = await renter.api('get', '/api/wallet/transactions');
    expect(history.body.map((t) => [t.type, t.amount, t.balanceAfter])).toEqual([
      ['withdrawal', -5000, 15000],
      ['topup', 20000, 20000]
    ]);
    expect(history.headers['x-total-count']).toBe('2');
  });

  test('two debits racing for the same money: only one wins', async () => {
    const racer = await makeUser('client');
    await racer.api('post', '/api/wallet/topup').send({ amount: 1000 }).expect(201);
    const results = await Promise.all([
      racer.api('post', '/api/wallet/withdraw').send({ amount: 800 }),
      racer.api('post', '/api/wallet/withdraw').send({ amount: 800 })
    ]);
    expect(results.map((r) => r.status).sort()).toEqual([201, 402]);
    expect(await balance(racer)).toBe(200);
  });

  test('wallet rental: cost + deposit held, refunded in full if declined or cancelled', async () => {
    const poor = await makeUser('client');
    const refused = await poor.api('post', `/api/tools/${tool._id}/rent`).send({ days: 2, paymentMethod: 'wallet' });
    expect(refused.status).toBe(402);
    expect(await Rental.countDocuments({ renter: poor.id })).toBe(0);

    const a = await renter.api('post', `/api/tools/${tool._id}/rent`).send({ days: 2, paymentMethod: 'wallet' });
    expect(a.body.payment).toMatchObject({ method: 'wallet', status: 'held', amount: 2000, deposit: 3000, fee: 200, net: 1800 });
    expect(await balance(renter)).toBe(10000);
    const declined = await supplier.api('post', `/api/rentals/${a.body._id}/reject`).send({ reason: 'Booked that week' });
    expect(declined.body.payment.status).toBe('refunded');
    expect(await balance(renter)).toBe(15000);

    const b = await renter.api('post', `/api/tools/${tool._id}/rent`).send({ days: 1, paymentMethod: 'wallet' });
    expect(await balance(renter)).toBe(11000);
    await renter.api('post', `/api/rentals/${b.body._id}/cancel`).expect(200);
    expect(await balance(renter)).toBe(15000);
  });

  test('on-time return pays the supplier (minus fee) and returns the whole deposit', async () => {
    const r = await renter.api('post', `/api/tools/${tool._id}/rent`).send({ days: 2, paymentMethod: 'wallet' });
    await supplier.api('post', `/api/rentals/${r.body._id}/approve`).expect(200);
    expect((await supplier.api('get', '/api/wallet')).body.incoming).toBe(1800);

    const returned = await supplier.api('post', `/api/rentals/${r.body._id}/return`);
    expect(returned.body).toMatchObject({ status: 'returned', lateDays: 0, lateFee: 0 });
    expect(returned.body.payment.status).toBe('released');
    expect(await balance(supplier)).toBe(1800);
    expect(await balance(renter)).toBe(13000); // paid 2000, deposit back
    expect(await Transaction.countDocuments({ type: 'platform_fee', rental: r.body._id, amount: 200 })).toBe(1);
  });

  test('a late return is charged per day from the deposit, capped at the deposit', async () => {
    const r = await renter.api('post', `/api/tools/${tool._id}/rent`).send({ days: 1, paymentMethod: 'wallet' });
    await supplier.api('post', `/api/rentals/${r.body._id}/approve`).expect(200);
    // Two days overdue.
    await Rental.updateOne({ _id: r.body._id }, { $set: { endDate: new Date(Date.now() - 1.5 * DAY) } });
    const overdue = await renter.api('get', `/api/rentals/${r.body._id}`);
    expect(overdue.body).toMatchObject({ overdue: true, lateDays: 2, lateFee: 2000 });

    const before = { renter: await balance(renter), supplier: await balance(supplier) };
    const returned = await supplier.api('post', `/api/rentals/${r.body._id}/return`);
    expect(returned.body).toMatchObject({ lateDays: 2, lateFee: 2000 });
    expect(await balance(supplier)).toBe(before.supplier + 900 + 2000); // rental net + late fee
    expect(await balance(renter)).toBe(before.renter + 1000); // deposit 3000 − 2000

    // Ten days late can never cost more than the deposit.
    const long = await renter.api('post', `/api/tools/${tool._id}/rent`).send({ days: 1, paymentMethod: 'wallet' });
    await supplier.api('post', `/api/rentals/${long.body._id}/approve`).expect(200);
    await Rental.updateOne({ _id: long.body._id }, { $set: { endDate: new Date(Date.now() - 9.5 * DAY) } });
    expect((await supplier.api('post', `/api/rentals/${long.body._id}/return`)).body.lateFee).toBe(3000);
  });

  test('cash rentals move no wallet money', async () => {
    const before = await balance(renter);
    const r = await renter.api('post', `/api/tools/${tool._id}/rent`).send({ days: 3 });
    expect(r.body.payment).toMatchObject({ method: 'cash', status: 'cash_due', amount: 3000 });
    await supplier.api('post', `/api/rentals/${r.body._id}/approve`).expect(200);
    const returned = await supplier.api('post', `/api/rentals/${r.body._id}/return`);
    expect(returned.body.payment.status).toBe('cash_paid');
    expect(await balance(renter)).toBe(before);
  });

  test('installment plan: monthly payments by wallet or cash, completes when all are paid', async () => {
    const stock = (await Tool.findById(tool._id)).stock;
    const plan = await renter.api('post', `/api/tools/${tool._id}/purchase`).send({});
    expect(plan.body).toMatchObject({ type: 'installment', monthsTotal: 3, monthsPaid: 0, monthlyAmount: 4000, monthsRemaining: 3 });
    await renter.api('post', `/api/rentals/${plan.body._id}/pay-installment`).expect(400); // not approved yet
    await supplier.api('post', `/api/rentals/${plan.body._id}/approve`).expect(200);
    expect((await Tool.findById(tool._id)).stock).toBe(stock - 1);

    const before = { renter: await balance(renter), supplier: await balance(supplier) };
    await supplier.api('post', `/api/rentals/${plan.body._id}/pay-installment`).expect(403);
    const first = await renter.api('post', `/api/rentals/${plan.body._id}/pay-installment`);
    expect(first.body).toMatchObject({ monthsPaid: 1, monthsRemaining: 2, status: 'active' });
    expect(await balance(renter)).toBe(before.renter - 4000);
    expect(await balance(supplier)).toBe(before.supplier + 3600);

    await renter.api('post', `/api/rentals/${plan.body._id}/record-installment`).expect(403);
    const second = await supplier.api('post', `/api/rentals/${plan.body._id}/record-installment`).send({});
    expect(second.body.monthsPaid).toBe(2);
    // An empty wallet can't pay; the plan simply stays where it is.
    const short = await renter.api('post', `/api/rentals/${plan.body._id}/pay-installment`);
    expect(short.status).toBe(402);
    expect((await renter.api('get', `/api/rentals/${plan.body._id}`)).body.monthsPaid).toBe(2);
    await renter.api('post', '/api/wallet/topup').send({ amount: 5000 }).expect(201);
    const last = await renter.api('post', `/api/rentals/${plan.body._id}/pay-installment`);
    expect(last.body).toMatchObject({ monthsPaid: 3, monthsRemaining: 0, status: 'completed' });
    await renter.api('post', `/api/rentals/${plan.body._id}/pay-installment`).expect(400);
    // A bought tool stays sold.
    expect((await Tool.findById(tool._id)).stock).toBe(stock - 1);

    const cashPlan = await renter.api('post', `/api/tools/${tool._id}/purchase`).send({});
    await supplier.api('post', `/api/rentals/${cashPlan.body._id}/approve`).expect(200);
    const settled = await supplier.api('post', `/api/rentals/${cashPlan.body._id}/record-installment`).send({ all: true });
    expect(settled.body).toMatchObject({ status: 'completed', monthsPaid: 3 });
  });

  test('deleting a tool refunds wallet-paid pending requests', async () => {
    const extra = (await supplier.api('post', '/api/tools').send({ name: 'Tile cutter', rentPricePerDay: 500, deposit: 1000 })).body;
    const before = await balance(renter);
    await renter.api('post', `/api/tools/${extra._id}/rent`).send({ days: 2, paymentMethod: 'wallet' }).expect(201);
    expect(await balance(renter)).toBe(before - 2000);
    await supplier.api('delete', `/api/tools/${extra._id}`).expect(200);
    expect(await balance(renter)).toBe(before);
  });
});
