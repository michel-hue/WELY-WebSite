import { NotificationsService } from '../src/notifications/notifications.service.js';
import { PUSH_SENDER } from '../src/notifications/push/push-sender.js';
import { InMemoryPushSender } from './utils/in-memory-push-sender.js';
import { bearer, bootTestApp, loginAs, type TestApp } from './utils/test-app.js';

describe('Notifications', () => {
  let t: TestApp;
  let notifications: NotificationsService;
  const push = new InMemoryPushSender();

  beforeAll(async () => {
    t = await bootTestApp((b) => b.overrideProvider(PUSH_SENDER).useValue(push));
    notifications = t.app.get(NotificationsService);
  });
  afterAll(async () => {
    await t.app.close();
  });

  it('stores, lists and marks a notification as read', async () => {
    const a = await loginAs(t, '0703000001', 'Awa');
    await notifications.notify(a.user.id, 'request_accepted', { title: 'Demande acceptée', body: 'Bonne nouvelle !' });

    const list = await t.http().get('/v1/me/notifications').set(bearer(a)).expect(200);
    expect(list.body.nextCursor).toBeNull();
    expect(list.body.data).toEqual([
      expect.objectContaining({ type: 'request_accepted', title: 'Demande acceptée', body: 'Bonne nouvelle !', readAt: null }),
    ]);
    await t.http().get('/v1/me/notifications/unread-count').set(bearer(a)).expect(200, { count: 1 });

    await t.http().post(`/v1/me/notifications/${list.body.data[0].id}/read`).set(bearer(a)).expect(204);
    await t.http().get('/v1/me/notifications/unread-count').set(bearer(a)).expect(200, { count: 0 });
  });

  it('paginates with a cursor without duplicates or gaps', async () => {
    const a = await loginAs(t, '0703000006', 'Awa');
    for (const i of [1, 2, 3, 4, 5]) await notifications.notify(a.user.id, 'listing_expired', { title: `N${i}`, body: '…' });
    const titles: string[] = [];
    let cursor: string | null = null;
    do {
      const res = await t
        .http()
        .get('/v1/me/notifications')
        .query({ limit: 2, ...(cursor ? { cursor } : {}) })
        .set(bearer(a))
        .expect(200);
      titles.push(...res.body.data.map((n: { title: string }) => n.title));
      cursor = res.body.nextCursor;
    } while (cursor);
    expect(titles).toEqual(['N5', 'N4', 'N3', 'N2', 'N1']);
  });

  it('never shows a notification to another user', async () => {
    const a = await loginAs(t, '0703000002', 'Awa');
    const b = await loginAs(t, '0703000003', 'Bakary');
    await notifications.notify(a.user.id, 'listing_expired', { title: 'Annonce expirée', body: '…' });
    const list = await t.http().get('/v1/me/notifications').set(bearer(b)).expect(200);
    expect(list.body.data).toEqual([]);
    const id = (await t.http().get('/v1/me/notifications').set(bearer(a))).body.data[0].id;
    await t.http().post(`/v1/me/notifications/${id}/read`).set(bearer(b)).expect(404);
  });

  it('pushes to registered devices and marks all as read', async () => {
    const a = await loginAs(t, '0703000004', 'Awa');
    await t.http().put('/v1/me/devices/fcm-token-123').set(bearer(a)).send({ platform: 'android' }).expect(204);
    await notifications.notify(a.user.id, 'request_received', { title: 'Nouvelle demande', body: 'Yao', requestId: '00000000-0000-0000-0000-000000000001' });
    expect(push.sent.at(-1)).toMatchObject({
      tokens: ['fcm-token-123'],
      message: { title: 'Nouvelle demande', body: 'Yao', data: { type: 'request_received', requestId: '00000000-0000-0000-0000-000000000001' } },
    });

    await t.http().post('/v1/me/notifications/read-all').set(bearer(a)).expect(204);
    await t.http().get('/v1/me/notifications/unread-count').set(bearer(a)).expect(200, { count: 0 });
  });

  it('drops device tokens reported invalid by the push service', async () => {
    const a = await loginAs(t, '0703000005', 'Awa');
    await t.http().put('/v1/me/devices/dead-token').set(bearer(a)).send({ platform: 'ios' }).expect(204);
    push.invalid.add('dead-token');
    await notifications.notify(a.user.id, 'request_refused', { title: 'Refusée', body: '…' });
    const [{ count }] = await t.ds.query(`SELECT count(*)::int AS count FROM devices WHERE token = 'dead-token'`);
    expect(count).toBe(0);
  });
});
