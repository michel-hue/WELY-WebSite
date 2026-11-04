import { bootTestApp, type TestApp } from './utils/test-app.js';

describe('Socle HTTP', () => {
  let t: TestApp;

  beforeAll(async () => {
    t = await bootTestApp();
  });
  afterAll(async () => {
    await t.app.close();
  });

  it('GET /health reports ok with the database up', async () => {
    const res = await t.http().get('/health').expect(200);
    expect(res.body).toEqual({ status: 'ok', db: 'up' });
  });

  it('unknown route returns the uniform NOT_FOUND error', async () => {
    const res = await t.http().get('/v1/nope').expect(404);
    expect(res.body).toEqual({ error: { code: 'NOT_FOUND', message: 'Ressource introuvable.' } });
  });

  it('malformed JSON body returns BAD_REQUEST', async () => {
    const res = await t
      .http()
      .post('/v1/nope')
      .set('Content-Type', 'application/json')
      .send('{"oops":')
      .expect(400);
    expect(res.body.error.code).toBe('BAD_REQUEST');
  });
});
