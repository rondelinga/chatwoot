import { describe, it, expect } from 'vitest';
import { isInternalWidgetMessage } from '../messageVisibility';
import { MESSAGE_TYPE } from '../constants';

describe('isInternalWidgetMessage', () => {
  it('returns true for activity messages', () => {
    expect(
      isInternalWidgetMessage({
        message_type: MESSAGE_TYPE.ACTIVITY,
        content: 'x',
      })
    ).toBe(true);
  });

  it('returns true for private messages', () => {
    expect(
      isInternalWidgetMessage({
        message_type: MESSAGE_TYPE.OUTGOING,
        private: true,
      })
    ).toBe(true);
  });

  it('returns false for public outgoing messages', () => {
    expect(
      isInternalWidgetMessage({
        message_type: MESSAGE_TYPE.OUTGOING,
        private: false,
      })
    ).toBe(false);
  });
});
