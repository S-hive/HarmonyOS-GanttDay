import { describe, it, expect } from '@ohos/hypium';
import { GanttGeometry } from '../../../main/ets/domain/gantt/GanttGeometry';
import { WallClock } from '../../../main/ets/domain/time/WallClock';

export default function ganttGeometryTest() {
  describe('GanttGeometry', () => {
    const day = WallClock.minutes(new Date(2026, 7, 8));
    const geo = new GanttGeometry(day + 8 * 60, day + 22 * 60, 1400);

    it('xOf_maps_viewStart_to_0_and_viewEnd_to_width', 0, () => {
      expect(geo.xOf(day + 8 * 60)).assertEqual(0);
      expect(geo.xOf(day + 22 * 60)).assertEqual(1400);
    });

    it('timeOf_is_inverse_of_xOf_at_hour_marks', 0, () => {
      expect(geo.timeOf(100)).assertEqual(day + 9 * 60);
    });

    it('snap_rounds_8_07_down_and_8_08_up', 0, () => {
      expect(geo.snap(day + 8 * 60 + 7)).assertEqual(day + 8 * 60);
      expect(geo.snap(day + 8 * 60 + 8)).assertEqual(day + 8 * 60 + 15);
    });

    it('snap_keeps_exact_quarter_marks_unchanged', 0, () => {
      expect(geo.snap(day + 9 * 60)).assertEqual(day + 9 * 60);
      expect(geo.snap(day + 9 * 60 + 45)).assertEqual(day + 9 * 60 + 45);
    });

    it('clampDuration_enforces_15_minute_minimum', 0, () => {
      const start = day + 9 * 60;
      expect(geo.clampDuration(start, start + 5)).assertEqual(start + 15);
      expect(geo.clampDuration(start, start - 30)).assertEqual(start + 15);
      expect(geo.clampDuration(start, start + 45)).assertEqual(start + 45);
    });
  });
}
