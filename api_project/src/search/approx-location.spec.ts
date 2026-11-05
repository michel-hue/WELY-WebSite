import { approxLocation } from './approx-location.js';

const haversine = (a: { lat: number; lng: number }, b: { lat: number; lng: number }) => {
  const R = 6_371_000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
};

describe('approxLocation', () => {
  const point = { lat: 5.3599, lng: -3.9873 };
  const ids = ['0b7e1f2a-1111-4c3d-9e8f-000000000001', '5f0a9d2c-2222-4b1a-8c7d-000000000002', 'e3c4b5a6-3333-4f2e-a1b0-000000000003'];

  it('is stable for the same listing', () => {
    expect(approxLocation(ids[0], point)).toEqual(approxLocation(ids[0], point));
  });

  it.each(ids)('moves the point by 150 to 600 m (%s)', (id) => {
    const p = approxLocation(id, point)!;
    expect(p).not.toEqual(point);
    const d = haversine(point, p);
    expect(d).toBeGreaterThanOrEqual(150);
    expect(d).toBeLessThanOrEqual(600);
  });

  it('rounds to 4 decimals', () => {
    const p = approxLocation(ids[1], point)!;
    expect(Number(p.lat.toFixed(4))).toBe(p.lat);
    expect(Number(p.lng.toFixed(4))).toBe(p.lng);
  });

  it('returns null without a point', () => {
    expect(approxLocation(ids[2], null)).toBeNull();
  });
});
