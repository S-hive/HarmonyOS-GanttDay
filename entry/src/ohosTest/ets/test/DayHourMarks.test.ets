import { describe, it, expect } from '@ohos/hypium';
import {
  dayHourMark,
  layoutDateBadge,
  skipBodyHourTick
} from '../../../main/ets/domain/gantt/DayHourMarks';
import { WallClock } from '../../../main/ets/domain/time/WallClock';

export default function dayHourMarksTest() {
  describe('DayHourMarks', () => {
    const day0 = WallClock.minutes(new Date(2026, 8, 14));

    it('page_day_hours_are_clock_labels', 0, () => {
      const mark = dayHourMark(day0, 20 * 60);
      expect(mark.isDayBoundary).assertFalse();
      expect(mark.label).assertEqual('20:00');
    });

    it('next_midnight_is_date_box_not_0_00', 0, () => {
      const mark = dayHourMark(day0, 24 * 60);
      expect(mark.isDayBoundary).assertTrue();
      expect(mark.label).assertEqual('9/15');
      expect(mark.emphasized).assertTrue();
    });

    it('page_day_midnight_is_not_a_boundary', 0, () => {
      const mark = dayHourMark(day0, 0);
      expect(mark.isDayBoundary).assertFalse();
      expect(mark.label).assertEqual('0:00');
    });

    it('next_midnight_has_no_body_hour_tick', 0, () => {
      expect(skipBodyHourTick(24 * 60)).assertTrue();
      expect(skipBodyHourTick(0)).assertFalse();
      expect(skipBodyHourTick(20 * 60)).assertFalse();
    });

    it('date_badge_box_stays_inside_header', 0, () => {
      const box = layoutDateBadge(10, 28, 11, 32, 5);
      expect(box.w).assertEqual(38);
      expect(box.h).assertEqual(21);
      expect(box.y >= 1).assertTrue();
      expect(box.y + box.h <= 31).assertTrue();
    });

    it('date_badge_uses_same_pad_on_all_sides', 0, () => {
      const box = layoutDateBadge(16, 90, 24, 53, 5);
      expect(box.w - 90).assertEqual(10);
      expect(box.h - 24).assertEqual(10);
      expect(box.x).assertEqual(11);
    });
  });
}
