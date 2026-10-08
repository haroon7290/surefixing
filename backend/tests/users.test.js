const { connect, disconnect, makeUser } = require('./helpers');

beforeAll(connect);
afterAll(disconnect);

describe('profiles, discovery, dashboards, notifications', () => {
  let client;
  let tech;

  beforeAll(async () => {
    client = await makeUser('client');
    tech = await makeUser('technician');
    await makeUser('technician', { profile: { skills: ['painting'], city: 'Karachi', rating: 4.9 } });
  });

  test('profile update is whitelisted and validated', async () => {
    const res = await tech.api('patch', '/api/users/me').send({
      headline: 'Plumbing pro',
      skills: ['Plumbing', 'plumbing', ' Electrical '],
      hourlyRate: 1500,
      experienceYears: 7,
      city: 'Lahore',
      isAvailable: false,
      role: 'admin',
      rating: 5,
      kycStatus: 'approved'
    });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ role: 'technician', rating: 0, kycStatus: 'none', isAvailable: false, hourlyRate: 1500 });
    expect(res.body.skills).toEqual(['plumbing', 'electrical']);
    await tech.api('patch', '/api/users/me').send({ skills: 'plumbing' }).expect(400);
    await tech.api('patch', '/api/users/me').send({ hourlyRate: -5 }).expect(400);
  });

  test('other users see a profile without private contact details', async () => {
    const res = await client.api('get', `/api/users/${tech.id}`);
    expect(res.body.name).toBeTruthy();
    expect(res.body.email).toBeUndefined();
    expect(res.body.phone).toBeUndefined();
    const self = await tech.api('get', `/api/users/${tech.id}`);
    expect(self.body.email).toBe(tech.email);
  });

  test('technician directory filters', async () => {
    const byCat = await client.api('get', '/api/users/technicians?category=painting');
    expect(byCat.body).toHaveLength(1);
    expect(byCat.headers['x-total-count']).toBe('1');
    const byCity = await client.api('get', '/api/users/technicians?city=lahore');
    expect(byCity.body.map((t) => t.id)).toEqual([tech.id]);
    const available = await client.api('get', '/api/users/technicians?available=1');
    expect(available.body.map((t) => t.id)).not.toContain(tech.id);
    const text = await client.api('get', '/api/users/technicians?q=plumbing%20pro');
    expect(text.body).toHaveLength(1);
  });

  test('dashboard summary per role', async () => {
    await client.api('post', '/api/jobs').send({ title: 'Fix tap', description: 'Tap is dripping constantly', requestedTechnician: tech.id }).expect(201);
    const c = await client.api('get', '/api/users/me/summary');
    expect(c.body.jobs).toEqual({ pending: 1 });
    const t = await tech.api('get', '/api/users/me/summary');
    expect(t.body).toMatchObject({ requests: 1, activeJobs: 0, earnings: 0, unreadNotifications: 1 });
  });

  test('notifications: unread count and read-all', async () => {
    const count = await tech.api('get', '/api/users/me/notifications/unread-count');
    expect(count.body.count).toBe(1);
    const list = await tech.api('get', '/api/users/me/notifications');
    expect(list.body[0]).toMatchObject({ type: 'request', readAt: null });
    expect(list.body[0].data.jobId).toBeTruthy();
    await tech.api('post', '/api/users/me/notifications/read-all').expect(200);
    const after = await tech.api('get', '/api/users/me/notifications/unread-count');
    expect(after.body.count).toBe(0);
  });

  test('avatar upload accepts images only', async () => {
    const png = Buffer.from('89504e470d0a1a0a0000000d49484452', 'hex');
    const ok = await client.api('post', '/api/users/me/avatar').attach('avatar', png, 'me.png');
    expect(ok.status).toBe(200);
    expect(ok.body.avatar).toMatch(/\.png$/);
    await client.api('post', '/api/users/me/avatar').expect(400);
  });

  test('meta catalog is public', async () => {
    const { request, app } = require('./helpers');
    const res = await request(app).get('/api/meta');
    expect(res.body.serviceCategories.map((c) => c.key)).toContain('plumbing');
    expect(res.body.urgencyLevels).toEqual(['low', 'normal', 'high', 'emergency']);
  });
});
