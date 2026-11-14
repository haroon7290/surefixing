const { connect, disconnect, makeUser, fund } = require('./helpers');
const Notification = require('../src/models/Notification');
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

  test('deposits are credited only when an admin approves them', async () => {
    const admin = await makeUser('admin');
    await renter.api('post', '/api/admin/payment-accounts').send({ provider: 'X', accountTitle: 'Y', accountNumber: '1234' }).expect(403);
    const account = (
      await admin.api('post', '/api/admin/payment-accounts').send({ kind: 'bank', provider: 'Meezan Bank', accountTitle: 'SureFix', accountNumber: '0101-0104567890' })
    ).body;
    const hidden = (await admin.api('post', '/api/admin/payment-accounts').send({ provider: 'Old Bank', accountTitle: 'SureFix', accountNumber: '9999', active: false })).body;
    const listed = (await renter.api('get', '/api/wallet/accounts')).body.map((a) => a._id);
    expect(listed).toContain(account._id);
    expect(listed).not.toContain(hidden._id);

    const send = (amount, transactionId, accountId = account._id) => renter.api('post', '/api/wallet/deposits').send({ accountId, amount, transactionId });
    await send(50, 'TX-1001').expect(400); // below the minimum
    await send(1000, '').expect(400); // no transaction ID
    await send(1000, 'TX-2000', hidden._id).expect(400); // hidden account

    const sent = await send(20000, 'TX-1001');
    expect(sent.status).toBe(201);
    expect(sent.body).toMatchObject({ kind: 'deposit', status: 'pending', amount: 20000, transactionId: 'TX-1001' });
    expect(sent.body.sentTo).toMatchObject({ provider: 'Meezan Bank', accountNumber: '0101-0104567890' });
    expect(await balance(renter)).toBe(0);
    expect((await renter.api('get', '/api/wallet')).body).toMatchObject({ balance: 0, pendingDeposits: 20000 });
    // The same transfer can't be claimed twice, however it is typed.
    expect((await send(20000, 'tx 1001')).status).toBe(409);

    await renter.api('post', `/api/admin/wallet-requests/${sent.body._id}/approve`).expect(403);
    const queue = (await admin.api('get', '/api/admin/wallet-requests?kind=deposit')).body;
    expect(queue.map((r) => r._id)).toContain(sent.body._id);
    expect(queue[0].user.name).toBeTruthy();

    // Two admins clicking at once: credited exactly once.
    const clicks = await Promise.all([
      admin.api('post', `/api/admin/wallet-requests/${sent.body._id}/approve`).send({}),
      admin.api('post', `/api/admin/wallet-requests/${sent.body._id}/approve`).send({})
    ]);
    expect(clicks.map((r) => r.status).sort()).toEqual([200, 409]);
    expect(await balance(renter)).toBe(20000);
    expect(await Notification.exists({ user: renter.id, type: 'wallet', title: 'Deposit approved' })).toBeTruthy();

    // A rejected deposit adds nothing and frees nothing; a pending one can be taken back.
    const fake = (await send(9000, 'TX-FAKE')).body;
    await admin.api('post', `/api/admin/wallet-requests/${fake._id}/reject`).send({}).expect(400); // needs a reason
    const rejected = await admin.api('post', `/api/admin/wallet-requests/${fake._id}/reject`).send({ reason: 'Not in our statement' });
    expect(rejected.body).toMatchObject({ status: 'rejected', adminNote: 'Not in our statement' });
    const mistake = (await send(700, 'TX-OOPS')).body;
    await renter.api('post', `/api/wallet/requests/${mistake._id}/cancel`).expect(200);
    await renter.api('post', `/api/wallet/requests/${mistake._id}/cancel`).expect(409);
    // An admin can correct the amount to what actually arrived.
    const short = (await send(3000, 'TX-SHORT')).body;
    const corrected = await admin.api('post', `/api/admin/wallet-requests/${short._id}/approve`).send({ amount: 2500 });
    expect(corrected.body.amount).toBe(2500);
    expect(await balance(renter)).toBe(22500);
    expect((await admin.api('get', '/api/admin/stats')).body.pendingDeposits).toBe(0);
  });

  test('withdrawals leave the wallet at once and come back if rejected', async () => {
    const admin = await makeUser('admin');
    const payout = { method: 'mobile_wallet', provider: 'JazzCash', accountTitle: 'Renter', accountNumber: '0300-1234567' };
    await renter.api('post', '/api/wallet/withdrawals').send({ ...payout, amount: 100 }).expect(400); // below the minimum
    await renter.api('post', '/api/wallet/withdrawals').send({ amount: 1000 }).expect(400); // no account
    const over = await renter.api('post', '/api/wallet/withdrawals').send({ ...payout, amount: 50000 });
    expect(over.status).toBe(402);
    expect(over.body.code).toBe('insufficient_funds');

    const big = await renter.api('post', '/api/wallet/withdrawals').send({ ...payout, amount: 6500 });
    expect(big.status).toBe(201);
    expect(big.body).toMatchObject({ kind: 'withdrawal', status: 'pending', amount: 6500 });
    expect(await balance(renter)).toBe(16000);
    expect((await renter.api('get', '/api/users/me')).body.payoutAccount).toMatchObject(payout);
    expect((await admin.api('get', '/api/admin/stats')).body).toMatchObject({ pendingWithdrawals: 1, pendingWithdrawalsAmount: 6500 });

    const small = (await renter.api('post', '/api/wallet/withdrawals').send({ ...payout, amount: 1000 })).body;
    expect(await balance(renter)).toBe(15000);
    await admin.api('post', `/api/admin/wallet-requests/${small._id}/reject`).send({ reason: 'Account title does not match' }).expect(200);
    expect(await balance(renter)).toBe(16000);

    const paid = await admin.api('post', `/api/admin/wallet-requests/${big.body._id}/approve`).send({ reference: 'JC-REF-77' });
    expect(paid.body).toMatchObject({ status: 'approved', reference: 'JC-REF-77' });
    expect(await balance(renter)).toBe(16000); // already taken when requested
    await renter.api('post', `/api/wallet/requests/${big.body._id}/cancel`).expect(409);

    // Back to a round 15000 for the rental tests below.
    const last = (await renter.api('post', '/api/wallet/withdrawals').send({ ...payout, amount: 1000 })).body;
    await admin.api('post', `/api/admin/wallet-requests/${last._id}/approve`).send({}).expect(200);
    expect(await balance(renter)).toBe(15000);

    const history = (await renter.api('get', '/api/wallet/transactions')).body.map((t) => [t.type, t.amount]);
    expect(history.slice(0, 4)).toEqual([
      ['withdrawal', -1000],
      ['withdrawal_reversed', 1000],
      ['withdrawal', -1000],
      ['withdrawal', -6500]
    ]);
    expect((await renter.api('get', '/api/wallet/requests?kind=withdrawal')).body).toHaveLength(3);
  });

  test('two withdrawals racing for the same money: only one wins', async () => {
    const racer = await makeUser('client');
    await fund(racer, 1000);
    const payout = { method: 'bank', provider: 'HBL', accountTitle: 'Racer', accountNumber: '00420001' };
    const results = await Promise.all([
      racer.api('post', '/api/wallet/withdrawals').send({ ...payout, amount: 800 }),
      racer.api('post', '/api/wallet/withdrawals').send({ ...payout, amount: 800 })
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
    await fund(renter, 5000);
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
