import { describe, it, expect } from '@ohos/hypium';
import { GanttGeometry } from '../../../main/ets/domain/gantt/GanttGeometry';
import {
  expandProbeFromOverscroll,
  proposeCreateAt,
  proposeMove,
  proposeResizeEnd,
  Span
} from '../../../main/ets/domain/gantt/DayGestureMath';
import { kDayViewMaxSpanMinutes } from '../../../main/ets/domain/gantt/DayVisibleRange';
import { Task } from '../../../main/ets/domain/models/Task';
import { WallClock } from '../../../main/ets/domain/time/WallClock';

function workTask(day: number, startHour: number, durationMinutes: number): Task {
  return new Task(
    't',
    'work',
    day + startHour * 60,
    day + startHour * 60 + durationMinutes,
    'azure',
    0
  );
}

export default function dayGestureMathTest() {
  describe('DayGestureMath', () => {
    const day = WallClock.minutes(new Date(2026, 7, 8));
    const geo = new GanttGeometry(day + 8 * 60, day + 22 * 60, 1400);

    it('proposeCreateAt_snaps_start_and_spans_60_minutes', 0, () => {
      const span: Span = proposeCreateAt(geo, geo.xOf(day + 9 * 60 + 7));
      expect(span.start).assertEqual(day + 9 * 60);
      expect(span.end).assertEqual(day + 10 * 60);
    });

    it('proposeMove_keeps_duration_and_shifts_one_hour', 0, () => {
      const moved = proposeMove(workTask(day, 9, 120), geo, 1400 / 14);
      expect(moved.plannedStart).assertEqual(day + 10 * 60);
      expect(moved.plannedEnd - moved.plannedStart).assertEqual(120);
    });

    it('proposeResizeEnd_snaps_10_08_to_10_15', 0, () => {
      const resized = proposeResizeEnd(workTask(day, 9, 120), geo, geo.xOf(day + 10 * 60 + 8));
      expect(resized.plannedStart).assertEqual(day + 9 * 60);
      expect(resized.plannedEnd).assertEqual(day + 10 * 60 + 15);
    });

    it('proposeResizeEnd_enforces_15_minute_minimum', 0, () => {
      const resized = proposeResizeEnd(workTask(day, 9, 120), geo, geo.xOf(day + 9 * 60));
      expect(resized.plannedStart).assertEqual(day + 9 * 60);
      expect(resized.plannedEnd).assertEqual(day + 9 * 60 + 15);
    });

    it('expandProbe_zero_push_stays_at_edge_base', 0, () => {
      const base = day + 22 * 60;
      const p = expandProbeFromOverscroll(
        day,
        day + kDayViewMaxSpanMinutes,
        base,
        100,
        0,
        true
      );
      expect(p).assertEqual(base);
    });

    it('expandProbe_small_push_opens_one_hour_from_fixed_base', 0, () => {
      const base = day + 22 * 60;
      const p1 = expandProbeFromOverscroll(
        day,
        day + kDayViewMaxSpanMinutes,
        base,
        100,
        10,
        true
      );
      expect(p1).assertEqual(base + 60);
      const p2 = expandProbeFromOverscroll(
        day,
        day + kDayViewMaxSpanMinutes,
        base,
        100,
        10,
        true
      );
      expect(p2).assertEqual(p1);
    });

    it('expandProbe_further_overscroll_opens_three_hours', 0, () => {
      const base = day + 22 * 60;
      const p = expandProbeFromOverscroll(
        day,
        day + kDayViewMaxSpanMinutes,
        base,
        100,
        250,
        true
      );
      expect(p).assertEqual(base + 3 * 60);
    });

    it('expandProbe_caps_at_7_days', 0, () => {
      const base = day + 22 * 60;
      const p = expandProbeFromOverscroll(
        day,
        day + kDayViewMaxSpanMinutes,
        base,
        10,
        100000,
        true
      );
      expect(p).assertEqual(day + kDayViewMaxSpanMinutes);
    });
  });
}
