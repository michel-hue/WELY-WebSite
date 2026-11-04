import { bootTestApp, loginAs, type TestApp } from './utils/test-app.js';

describe('Connexion sans mot de passe', () => {
  let t: TestApp;

  beforeAll(async () => {
    t = await bootTestApp();
  });
  afterAll(async () => {
    await t.app.close();
  });

  it('flags a new phone number as a new user', async () => {
    const res = await t.http().post('/v1/auth/otp/request').send({ phone: '0701000001' }).expect(202);
    expect(res.body).toEqual({ expiresInSeconds: 300, isNewUser: true });
    expect(t.otp.lastCodeFor('+2250701000001')).toMatch(/^\d{6}$/);
  });

  it('requires a name to create an account', async () => {
    await t.http().post('/v1/auth/otp/request').send({ phone: '0701000002' }).expect(202);
    const code = t.otp.lastCodeFor('+2250701000002');
    const res = await t.http().post('/v1/auth/otp/verify').send({ phone: '0701000002', code }).expect(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details).toEqual([expect.objectContaining({ field: 'name' })]);
  });

  it('creates the account and opens a session as a buyer', async () => {
    const session = await loginAs(t, '0701000003', 'Awa Koné');
    expect(session.accessToken).toBeTruthy();
    expect(session.refreshToken).toBeTruthy();
    expect(session.user).toMatchObject({ name: 'Awa Koné', phone: '+2250701000003', isSeller: false });
  });

  it('recognises the same person whatever the phone format', async () => {
    const a = await loginAs(t, '07 01 00 00 04', 'Yao');
    const b = await loginAs(t, '+225 0701000004');
    expect(b.user.id).toBe(a.user.id);
    expect(b.user.name).toBe('Yao');
  });

  it('rejects a wrong code', async () => {
    await t.http().post('/v1/auth/otp/request').send({ phone: '0701000005' }).expect(202);
    const res = await t
      .http()
      .post('/v1/auth/otp/verify')
      .send({ phone: '0701000005', code: '000000', name: 'X Y' })
      .expect(401);
    expect(res.body.error).toEqual({ code: 'OTP_INVALID', message: 'Code incorrect ou expiré.' });
  });

  it('rejects an invalid phone number', async () => {
    const res = await t.http().post('/v1/auth/otp/request').send({ phone: '123' }).expect(400);
    expect(res.body.error.code).toBe('INVALID_PHONE');
  });

  it('rotates the refresh token and refuses the old one', async () => {
    const s = await loginAs(t, '0701000006', 'Kouassi');
    const res = await t.http().post('/v1/auth/refresh').send({ refreshToken: s.refreshToken }).expect(200);
    expect(res.body.refreshToken).not.toBe(s.refreshToken);
    expect(res.body.user.id).toBe(s.user.id);
    const again = await t.http().post('/v1/auth/refresh').send({ refreshToken: s.refreshToken }).expect(401);
    expect(again.body.error.code).toBe('REFRESH_INVALID');
    // Réutiliser un jeton déjà remplacé révoque toute la famille, y compris le nouveau.
    await t.http().post('/v1/auth/refresh').send({ refreshToken: res.body.refreshToken }).expect(401);
  });

  it('logs out by revoking the refresh token', async () => {
    const s = await loginAs(t, '0701000007', 'Fatou');
    await t.http().post('/v1/auth/logout').send({ refreshToken: s.refreshToken }).expect(204);
    await t.http().post('/v1/auth/refresh').send({ refreshToken: s.refreshToken }).expect(401);
  });

  it('refuses to resend a code within 60 seconds', async () => {
    await t.http().post('/v1/auth/otp/request').send({ phone: '0701000008' }).expect(202);
    const res = await t.http().post('/v1/auth/otp/request').send({ phone: '0701000008' }).expect(429);
    expect(res.body.error.code).toBe('OTP_RESEND_TOO_SOON');
  });
});
