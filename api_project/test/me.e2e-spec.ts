import { bearer, bootTestApp, loginAs, type TestApp } from './utils/test-app.js';

describe('Profil et mode vendeur', () => {
  let t: TestApp;

  beforeAll(async () => {
    t = await bootTestApp();
  });
  afterAll(async () => {
    await t.app.close();
  });

  it('requires a session', async () => {
    const res = await t.http().get('/v1/me').expect(401);
    expect(res.body.error).toEqual({ code: 'UNAUTHORIZED', message: 'Connexion requise.' });
  });

  it('returns and updates the profile', async () => {
    const s = await loginAs(t, '0702000001', 'Awa');
    await t.http().get('/v1/me').set(bearer(s)).expect(200, s.user);
    const res = await t
      .http()
      .patch('/v1/me')
      .set(bearer(s))
      .send({ name: 'Awa Koné', whatsappPhone: '05 05 05 05 05' })
      .expect(200);
    expect(res.body).toMatchObject({ name: 'Awa Koné', whatsappPhone: '+2250505050505' });
  });

  it('rejects an invalid WhatsApp number', async () => {
    const s = await loginAs(t, '0702000002', 'Yao');
    const res = await t.http().patch('/v1/me').set(bearer(s)).send({ whatsappPhone: '12' }).expect(400);
    expect(res.body.error.code).toBe('INVALID_PHONE');
  });

  it('switches seller mode on and off', async () => {
    const s = await loginAs(t, '0702000003', 'Koffi');
    const on = await t.http().put('/v1/me/seller-mode').set(bearer(s)).send({ enabled: true }).expect(200);
    expect(on.body.isSeller).toBe(true);
    const off = await t.http().put('/v1/me/seller-mode').set(bearer(s)).send({ enabled: false }).expect(200);
    expect(off.body.isSeller).toBe(false);
  });
});
