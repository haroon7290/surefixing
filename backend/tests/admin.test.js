const { connect, disconnect, makeUser } = require('./helpers');

beforeAll(connect);
afterAll(disconnect);

describe('admin & trust and safety', () => {
  let admin;
  let client;
  let tech;

  beforeAll(async () => {
    admin = await makeUser('admin');
    client = await makeUser('client');
    tech = await makeUser('technician');
  });

  test('non-admins are blocked', async () => {
    await client.api('get', '/api/admin/stats').expect(403);
  });

  test('stats include breakdowns and 7-day series', async () => {
    const res = await admin.api('get', '/api/admin/stats');
    expect(res.status).toBe(200);
    expect(res.body.users).toBe(3);
    expect(res.body.usersByRole).toMatchObject({ admin: 1, client: 1, technician: 1 });
    expect(res.body.signupsLast7Days).toHaveLength(7);
    expect(res.body.signupsLast7Days.at(-1).count).toBe(3);
    expect(res.body).toHaveProperty('openReports', 0);
  });

  test('user search and suspend / reactivate', async () => {
    const found = await admin.api('get', `/api/admin/users?q=${encodeURIComponent(tech.email)}`);
    expect(found.body).toHaveLength(1);
    await admin.api('patch', `/api/admin/users/${admin.id}/status`).send({ status: 'suspended' }).expect(400);
    await admin.api('patch', `/api/admin/users/${tech.id}/status`).send({ status: 'suspended' }).expect(200);
    await tech.api('get', '/api/users/me').expect(403);
    await admin.api('patch', `/api/admin/users/${tech.id}/status`).send({ status: 'active' }).expect(200);
    await tech.api('get', '/api/users/me').expect(200);
  });

  test('reports: create, dedupe, resolve with suspension', async () => {
    await client.api('post', '/api/reports').send({ targetType: 'user', targetId: client.id, reason: 'spam' }).expect(400);
    const r = await client.api('post', '/api/reports').send({ targetType: 'user', targetId: tech.id, reason: 'no_show', details: 'Never came' });
    expect(r.status).toBe(201);
    expect(r.body.targetLabel).toMatch(/technician/);
    await client.api('post', '/api/reports').send({ targetType: 'user', targetId: tech.id, reason: 'no_show' }).expect(409);

    const queue = await admin.api('get', '/api/admin/reports?status=open');
    expect(queue.body).toHaveLength(1);
    const resolved = await admin.api('post', `/api/admin/reports/${r.body._id}/resolve`).send({ status: 'resolved', note: 'Warned', suspendUser: true });
    expect(resolved.body.status).toBe('resolved');
    await tech.api('get', '/api/users/me').expect(403);
    await admin.api('post', `/api/admin/reports/${r.body._id}/resolve`).send({ status: 'dismissed' }).expect(400);
  });

  test('KYC review flow', async () => {
    const supplier = await makeUser('supplier');
    // Images are mandatory.
    await supplier.api('post', '/api/kyc').field('fullName', 'Supplier Person').field('idType', 'cnic').field('idNumber', '35202-1').expect(400);
    const png = Buffer.from('89504e470d0a1a0a0000000d4948445200000001000000010806000000', 'hex');
    const sub = await supplier
      .api('post', '/api/kyc')
      .field('fullName', 'Supplier Person')
      .field('idType', 'cnic')
      .field('idNumber', '35202-1234567-1')
      .attach('idFront', png, 'front.png')
      .attach('selfie', png, 'selfie.png');
    expect(sub.status).toBe(201);
    const pending = await admin.api('get', '/api/admin/kyc?status=pending');
    expect(pending.body).toHaveLength(1);
    await admin.api('post', `/api/admin/kyc/${sub.body._id}/verify`).send({ decision: 'approved' }).expect(200);
    const me = await supplier.api('get', '/api/users/me');
    expect(me.body.kycStatus).toBe('approved');
    // Approved KYC is locked.
    await supplier
      .api('post', '/api/kyc')
      .field('fullName', 'Other')
      .field('idType', 'cnic')
      .field('idNumber', '1111-1')
      .attach('idFront', png, 'f.png')
      .attach('selfie', png, 's.png')
      .expect(400);
  });

  test('non-image uploads are refused', async () => {
    const supplier = await makeUser('supplier');
    const res = await supplier
      .api('post', '/api/kyc')
      .field('fullName', 'Supplier Person')
      .field('idType', 'cnic')
      .field('idNumber', '35202-1234567-1')
      .attach('idFront', Buffer.from('#!/bin/sh'), { filename: 'evil.sh', contentType: 'text/x-sh' });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/image/);
  });
});
