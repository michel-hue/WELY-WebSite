import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { SearchQuery } from './search-query.dto.js';

async function fieldsInError(raw: Record<string, unknown>): Promise<string[]> {
  const errors = await validate(plainToInstance(SearchQuery, raw));
  return errors.map((e) => e.property).sort();
}

describe('SearchQuery validation', () => {
  it('accepts an empty query', async () => {
    expect(await fieldsInError({})).toEqual([]);
  });

  it('requires offerType when filtering by price', async () => {
    expect(await fieldsInError({ priceMin: '100000' })).toEqual(['offerType']);
    expect(await fieldsInError({ priceMax: '100000', offerType: 'monthly' })).toEqual([]);
  });

  it('requires lng together with lat', async () => {
    expect(await fieldsInError({ lat: '5.36' })).toEqual(['lng']);
    expect(await fieldsInError({ lng: '-3.98' })).toEqual(['lat']);
  });

  it('requires offerType when sorting by price', async () => {
    expect(await fieldsInError({ sort: 'price_asc' })).toEqual(['offerType']);
  });

  it('requires coordinates when sorting by distance', async () => {
    expect(await fieldsInError({ sort: 'distance' })).toEqual(['sort']);
  });

  it('requires offerType=nightly with stay dates', async () => {
    expect(await fieldsInError({ checkIn: '2026-12-10', checkOut: '2026-12-12', offerType: 'monthly' })).toEqual([
      'offerType',
    ]);
    expect(await fieldsInError({ checkIn: '2026-12-10', checkOut: '2026-12-12', offerType: 'nightly' })).toEqual([]);
  });

  it('accepts repeated or comma-separated multi-values', async () => {
    const q = plainToInstance(SearchQuery, { propertyType: 'villa,house', amenities: ['pool', 'wifi'] });
    expect(q.propertyType).toEqual(['villa', 'house']);
    expect(q.amenities).toEqual(['pool', 'wifi']);
    expect(await validate(q)).toEqual([]);
  });
});
