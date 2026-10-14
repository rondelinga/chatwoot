import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import WootReports from '../WootReports.vue';

const buildContext = query => ({
  $route: { query },
  $router: { replace: vi.fn().mockResolvedValue() },
  isDefaultRangeReady: false,
});

describe('WootReports.vue', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-10-14T10:00:00Z'));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('opens on today when the URL has no date range', async () => {
    const context = buildContext({ business_hours: 'true' });

    await WootReports.methods.applyDefaultRange.call(context);

    const today = new Date();
    expect(context.$router.replace).toHaveBeenCalledWith({
      query: {
        business_hours: 'true',
        from: getUnixStartOfDay(today),
        to: getUnixEndOfDay(today),
        range: 'today',
      },
    });
    expect(context.isDefaultRangeReady).toBe(true);
  });

  it('keeps the range from the URL', async () => {
    const context = buildContext({ range: 'last7days', from: '1', to: '2' });

    await WootReports.methods.applyDefaultRange.call(context);

    expect(context.$router.replace).not.toHaveBeenCalled();
    expect(context.isDefaultRangeReady).toBe(true);
  });
});
