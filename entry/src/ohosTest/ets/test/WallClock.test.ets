import { describe, it, expect } from '@ohos/hypium';
import { WallClock } from '../../../main/ets/domain/time/WallClock';

export default function wallClockTest() {
  describe('WallClock', () => {
    it('roundtrip_clock_face', 0, () => {
      const dt = new Date(2026, 7, 8, 9, 15);
      const m = WallClock.minutes(dt);
      const back = WallClock.dateTime(m);
      expect(back.getFullYear()).assertEqual(2026);
      expect(back.getMonth()).assertEqual(7);
      expect(back.getDate()).assertEqual(8);
      expect(back.getHours()).assertEqual(9);
      expect(back.getMinutes()).assertEqual(15);
    });

    it('dayStart_and_dayEndExclusive', 0, () => {
      const noon = WallClock.minutes(new Date(2026, 7, 8, 12, 0));
      const start = WallClock.dayStart(noon);
      const end = WallClock.dayEndExclusive(noon);
      const startDt = WallClock.dateTime(start);
      const endDt = WallClock.dateTime(end);
      expect(startDt.getFullYear()).assertEqual(2026);
      expect(startDt.getMonth()).assertEqual(7);
      expect(startDt.getDate()).assertEqual(8);
      expect(startDt.getHours()).assertEqual(0);
      expect(endDt.getDate()).assertEqual(9);
      expect(end - start).assertEqual(24 * 60);
    });

    it('encoding_is_clock_face_only', 0, () => {
      const m = WallClock.minutes(new Date(2026, 7, 8, 9, 0));
      const epoch = Date.UTC(1970, 0, 1);
      const dayUtc = Date.UTC(2026, 7, 8);
      const daysSinceEpoch = Math.floor((dayUtc - epoch) / 86400000);
      expect(m).assertEqual(daysSinceEpoch * 1440 + 9 * 60);
    });

    it('midnight_is_its_own_dayStart', 0, () => {
      const mid = WallClock.minutes(new Date(2026, 7, 8));
      expect(WallClock.dayStart(mid)).assertEqual(mid);
      expect(WallClock.dayEndExclusive(mid)).assertEqual(mid + 1440);
    });
  });
}
