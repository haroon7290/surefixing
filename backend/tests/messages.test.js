const { connect, disconnect, makeUser } = require('./helpers');

beforeAll(connect);
afterAll(disconnect);

describe('job chat', () => {
  let client;
  let techA;
  let techB;
  let outsider;
  let job;

  beforeAll(async () => {
    client = await makeUser('client');
    techA = await makeUser('technician', { profile: { skills: ['plumbing'] } });
    techB = await makeUser('technician', { profile: { skills: ['plumbing'] } });
    outsider = await makeUser('technician');
    job = (
      await client.api('post', '/api/jobs').send({
        title: 'Leaking tap',
        description: 'The tap in the kitchen keeps dripping all night.',
        category: 'plumbing'
      })
    ).body;
    await techA.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 1000 }).expect(201);
    await techB.api('post', `/api/jobs/${job._id}/bids`).send({ amount: 1200 }).expect(201);
  });

  test('client can ask bidders questions before hiring (separate threads)', async () => {
    await client.api('post', `/api/messages/${job._id}`).send({ text: 'Hi A', to: techA.id }).expect(201);
    await client.api('post', `/api/messages/${job._id}`).send({ text: 'Hi B', to: techB.id }).expect(201);
    await techA.api('post', `/api/messages/${job._id}`).send({ text: 'Hello from A' }).expect(201);

    const threadA = await client.api('get', `/api/messages/${job._id}?with=${techA.id}`);
    expect(threadA.body.map((m) => m.text)).toEqual(['Hi A', 'Hello from A']);
    const threadB = await techB.api('get', `/api/messages/${job._id}`);
    expect(threadB.body.map((m) => m.text)).toEqual(['Hi B']);
  });

  test('client must say which technician when there is no hire yet', async () => {
    await client.api('post', `/api/messages/${job._id}`).send({ text: 'Hello?' }).expect(400);
  });

  test('outsiders and empty messages are rejected', async () => {
    await outsider.api('get', `/api/messages/${job._id}`).expect(403);
    await outsider.api('post', `/api/messages/${job._id}`).send({ text: 'spam' }).expect(403);
    await client.api('post', `/api/messages/${job._id}`).send({ text: '   ', to: techA.id }).expect(400);
    await client.api('post', `/api/messages/${job._id}`).send({ text: 'x', to: outsider.id }).expect(403);
  });

  test('inbox shows unread counts and reading a thread clears them', async () => {
    const inboxB = await techB.api('get', '/api/messages');
    expect(inboxB.body).toHaveLength(1);
    expect(inboxB.body[0]).toMatchObject({ jobTitle: 'Leaking tap', unread: 0 });

    await techA.api('post', `/api/messages/${job._id}`).send({ text: 'Are you there?' }).expect(201);
    const unread = await client.api('get', '/api/messages/unread-count');
    // "Hello from A" was already read when the client opened thread A.
    expect(unread.body.count).toBe(1);
    const inbox = await client.api('get', '/api/messages');
    const rowA = inbox.body.find((r) => r.other.id === techA.id);
    expect(rowA.unread).toBe(1);
    expect(rowA.lastMessage.text).toBe('Are you there?');

    await client.api('get', `/api/messages/${job._id}?with=${techA.id}`).expect(200);
    const after = await client.api('get', '/api/messages/unread-count');
    expect(after.body.count).toBe(0);
  });

  test('after hiring, the losing bidder can no longer send', async () => {
    const detail = await client.api('get', `/api/jobs/${job._id}`);
    const bidA = detail.body.bids.find((b) => b.technician._id === techA.id);
    await client.api('post', `/api/jobs/${job._id}/accept/${bidA._id}`).expect(200);
    await techB.api('post', `/api/messages/${job._id}`).send({ text: 'Still available' }).expect(403);
    // Client's default thread is now the hired technician.
    await client.api('post', `/api/messages/${job._id}`).send({ text: 'See you tomorrow' }).expect(201);
    const thread = await techA.api('get', `/api/messages/${job._id}`);
    expect(thread.body.at(-1).text).toBe('See you tomorrow');
  });
});
