const { connect, disconnect, makeUser } = require('./helpers');

beforeAll(connect);
afterAll(disconnect);

describe('SureFix Support conversations', () => {
  let client;
  let tech;
  let admin;
  let admin2;

  beforeAll(async () => {
    client = await makeUser('client');
    tech = await makeUser('technician');
    admin = await makeUser('admin');
    admin2 = await makeUser('admin');
  });

  test('an admin can message any user; the user sees SureFix Support, never the admin', async () => {
    const sent = await admin
      .api('post', `/api/messages/support/${client.id}`)
      .send({ text: 'Hi, we are looking into your dispute.', about: 'Job: Fix leaking sink' })
      .expect(201);
    expect(sent.body).toMatchObject({ fromSupport: true, thread: `support:${client.id}`, about: 'Job: Fix leaking sink' });

    const thread = await client.api('get', '/api/messages/support').expect(200);
    expect(thread.body).toHaveLength(1);
    expect(thread.body[0]).toMatchObject({ sender: 'support', fromSupport: true, text: 'Hi, we are looking into your dispute.', about: 'Job: Fix leaking sink' });
    expect(JSON.stringify(thread.body)).not.toContain(admin.id);
    expect(JSON.stringify(thread.body)).not.toContain(admin.user.name);

    const inbox = await client.api('get', '/api/messages').expect(200);
    const row = inbox.body.find((r) => r.kind === 'support');
    expect(row.other).toMatchObject({ id: 'support', name: 'SureFix Support', role: 'support' });
    expect(row.lastMessage.sender).toBe('support');
  });

  test('the user replies to the whole team; every admin sees it and who wrote what', async () => {
    const before = (await admin2.api('get', '/api/messages/unread-count')).body.count;
    await client.api('post', '/api/messages/support').send({ text: 'Thanks, he never came.' }).expect(201);
    expect((await admin2.api('get', '/api/messages/unread-count')).body.count).toBe(before + 1);

    const inbox = await admin2.api('get', '/api/messages').expect(200);
    const row = inbox.body.find((r) => r.kind === 'support' && r.supportUser === client.id);
    expect(row).toMatchObject({ unread: 1, other: { name: client.user.name } });

    const thread = await admin2.api('get', `/api/messages/support/${client.id}`).expect(200);
    expect(thread.body.map((m) => [m.fromSupport, m.senderName])).toEqual([
      [true, admin.user.name],
      [false, client.user.name]
    ]);
    // Reading clears it for the whole team.
    expect((await admin.api('get', '/api/messages/unread-count')).body.count).toBe(before);
  });

  test('unread counts for the user, and reading clears them', async () => {
    await admin2.api('post', `/api/messages/support/${client.id}`).send({ text: 'A technician will call you today.' }).expect(201);
    expect((await client.api('get', '/api/messages/unread-count')).body.count).toBe(1);
    await client.api('post', '/api/messages/support/read').expect(200);
    expect((await client.api('get', '/api/messages/unread-count')).body.count).toBe(0);
  });

  test('users start their own support chat; threads stay separate per user', async () => {
    await tech.api('post', '/api/messages/support').send({ text: 'My verification is stuck.' }).expect(201);
    const techThread = await tech.api('get', '/api/messages/support').expect(200);
    expect(techThread.body.map((m) => m.text)).toEqual(['My verification is stuck.']);
    const clientThread = await client.api('get', '/api/messages/support').expect(200);
    expect(clientThread.body.map((m) => m.text)).not.toContain('My verification is stuck.');
  });

  test('only admins speak as SureFix Support', async () => {
    await client.api('post', `/api/messages/support/${tech.id}`).send({ text: 'Pretending' }).expect(403);
    await client.api('get', `/api/messages/support/${tech.id}`).expect(403);
    await admin.api('post', '/api/messages/support').send({ text: 'x' }).expect(400);
    await admin.api('post', `/api/messages/support/${admin2.id}`).send({ text: 'x' }).expect(400);
    await admin.api('post', `/api/messages/support/${client.id}`).send({ text: '   ' }).expect(400);
  });

  test('support threads do not leak into job or tool inbox rows', async () => {
    const inbox = await client.api('get', '/api/messages').expect(200);
    expect(inbox.body.filter((r) => r.kind === 'support')).toHaveLength(1);
    expect(inbox.body.every((r) => ['job', 'tool', 'support'].includes(r.kind))).toBe(true);
  });
});

describe('admins can read any conversation between users', () => {
  test('list and read job chats, read-only, admins only', async () => {
    const admin = await makeUser('admin');
    const client = await makeUser('client');
    const tech = await makeUser('technician', { profile: { skills: ['plumbing'] } });
    const job = (await client.api('post', '/api/jobs').send({ title: 'Dripping kitchen tap', description: 'The kitchen tap drips all night long.', category: 'plumbing' })).body;
    await tech.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 1500 }).expect(201);
    await client.api('post', `/api/messages/${job._id}`).send({ text: 'Can you come today?', to: tech.id }).expect(201);
    await tech.api('post', `/api/messages/${job._id}`).send({ text: 'Yes, at 5 pm. Rs 1500 agreed.' }).expect(201);

    const list = await admin.api('get', '/api/admin/conversations').expect(200);
    const row = list.body.find((c) => String(c.jobId) === job._id);
    expect(row).toMatchObject({ kind: 'job', subject: 'Dripping kitchen tap', count: 2 });
    expect([row.a.name, row.b.name].sort()).toEqual([client.user.name, tech.user.name].sort());
    expect(row.lastMessage.text).toBe('Yes, at 5 pm. Rs 1500 agreed.');

    const filtered = await admin.api('get', '/api/admin/conversations?q=dripping').expect(200);
    expect(filtered.body.some((c) => String(c.jobId) === job._id)).toBe(true);

    const thread = await admin.api('get', `/api/admin/conversations/thread?job=${job._id}&a=${client.id}&b=${tech.id}`).expect(200);
    expect(thread.body.map((m) => [m.senderName, m.text])).toEqual([
      [client.user.name, 'Can you come today?'],
      [tech.user.name, 'Yes, at 5 pm. Rs 1500 agreed.']
    ]);
    // Reading as admin doesn't mark anything read for the client.
    expect((await client.api('get', '/api/messages/unread-count')).body.count).toBe(1);

    await client.api('get', '/api/admin/conversations').expect(403);
    await admin.api('get', `/api/admin/conversations/thread?a=${client.id}&b=${tech.id}`).expect(400);
  });
});
