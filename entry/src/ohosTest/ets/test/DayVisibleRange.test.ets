import { describe, it, expect } from '@ohos/hypium';
import { Task } from '../../../main/ets/domain/models/Task';
import { WallClock } from '../../../main/ets/domain/time/WallClock';
import {
  computeDayFitMinutes,
  daySpansTouchingDay
} from '../../../main/ets/domain/gantt/DayVisibleRange';

export default function dayVisibleRangeTest() {
  describe('DayVisibleRange', () => {
    const day0 = WallClock.minutes(new Date(2026, 7, 8));

    it('empty_tasks_fit_is_8_to_22', 0, () => {
      const fit = computeDayFitMinutes(8, 22, day0, [], []);
      expect(fit.start).assertEqual(8 * 60);
      expect(fit.end).assertEqual(22 * 60);
    });

    it('probe_past_22_lengthens_end_by_whole_hour', 0, () => {
      const fit = computeDayFitMinutes(8, 22, day0, [], [day0 + 22 * 60 + 1]);
      expect(fit.start).assertEqual(8 * 60);
      expect(fit.end).assertEqual(23 * 60);
    });

    it('day_spans_use_selected_day_clip', 0, () => {
      const t = new Task(
        'n',
        'night',
        day0 + 23 * 60,
        day0 + 25 * 60,
        'azure',
        0
      );
      const spans = daySpansTouchingDay([t], day0);
      expect(spans.length).assertEqual(1);
      expect(spans[0].start).assertEqual(day0 + 23 * 60);
      expect(spans[0].end).assertEqual(day0 + 24 * 60);
      const fit = computeDayFitMinutes(8, 22, day0, spans, []);
      expect(fit.end).assertEqual(24 * 60);
    });
  });
}
