import { validateStay } from './stay-dates.js';
import { AppError } from '../common/errors/app-error.js';

const TODAY = '2026-11-04';

function codeOf(fn: () => void): string | undefined {
  try {
    fn();
    return undefined;
  } catch (e) {
    expect(e).toBeInstanceOf(AppError);
    return (e as AppError).code;
  }
}

describe('validateStay', () => {
  it('accepts a stay starting today', () => {
    expect(codeOf(() => validateStay('2026-11-04', '2026-11-06', null, TODAY))).toBeUndefined();
  });

  it('rejects a departure on the arrival day', () => {
    expect(codeOf(() => validateStay('2026-12-10', '2026-12-10', null, TODAY))).toBe('INVALID_STAY_DATES');
  });

  it('rejects an arrival in the past', () => {
    expect(codeOf(() => validateStay('2026-11-03', '2026-11-05', null, TODAY))).toBe('INVALID_STAY_DATES');
  });

  it('rejects a stay shorter than the minimum nights', () => {
    expect(codeOf(() => validateStay('2026-12-10', '2026-12-12', 3, TODAY))).toBe('MIN_NIGHTS_NOT_MET');
    expect(codeOf(() => validateStay('2026-12-10', '2026-12-13', 3, TODAY))).toBeUndefined();
  });

  it('rejects impossible calendar dates', () => {
    expect(codeOf(() => validateStay('2026-02-30', '2026-03-02', null, TODAY))).toBe('INVALID_STAY_DATES');
  });
});
