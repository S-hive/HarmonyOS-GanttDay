import { describe, it, expect } from '@ohos/hypium';
import { DaySegmenter } from '../../../main/ets/domain/gantt/DaySegmenter';
import { GanttSegment } from '../../../main/ets/domain/models/GanttSegment';
import { Task } from '../../../main/ets/domain/models/Task';
import { WallClock } from '../../../main/ets/domain/time/WallClock';

function task(start: Date, end: Date, id: string = 'a'): Task {
  return new Task(
    id,
    'task',
    WallClock.minutes(start),
    WallClock.minutes(end),
    'azure',
    0
  );
}

export default function daySegmenterTest() {
  describe('DaySegmenter', () => {
    it('overnight_task_yields_segment_on_start_day_ending_at_midnight', 0, () => {
      const t = task(new Date(2026, 7, 8, 23, 0), new Date(2026, 7, 9, 1, 0));
      const segs = DaySegmenter.segmentsForDay(t, WallClock.minutes(new Date(2026, 7, 8, 12, 0)));
      expect(segs.length).assertEqual(1);
      expect(segs[0].start).assertEqual(t.plannedStart);
      expect(segs[0].end).assertEqual(WallClock.minutes(new Date(2026, 7, 9)));
    });

    it('overnight_task_yields_morning_segment_on_next_day', 0, () => {
      const t = task(new Date(2026, 7, 8, 23, 0), new Date(2026, 7, 9, 1, 0));
      const segs = DaySegmenter.segmentsForDay(t, WallClock.minutes(new Date(2026, 7, 9, 12, 0)));
      expect(segs.length).assertEqual(1);
      expect(segs[0].start).assertEqual(WallClock.minutes(new Date(2026, 7, 9)));
      expect(segs[0].end).assertEqual(t.plannedEnd);
    });

    it('task_ending_exactly_at_midnight_has_no_segment_on_next_day', 0, () => {
      const t = task(new Date(2026, 7, 8, 22, 0), new Date(2026, 7, 9, 0, 0), 'b');
      const segs = DaySegmenter.segmentsForDay(t, WallClock.minutes(new Date(2026, 7, 9, 12, 0)));
      expect(segs.length).assertEqual(0);
    });

    it('task_fully_inside_a_day_is_returned_unclipped', 0, () => {
      const t = task(new Date(2026, 7, 8, 9, 0), new Date(2026, 7, 8, 11, 0));
      const segs = DaySegmenter.segmentsForDay(t, WallClock.minutes(new Date(2026, 7, 8)));
      expect(segs[0].start).assertEqual(t.plannedStart);
      expect(segs[0].end).assertEqual(t.plannedEnd);
    });

    it('task_on_another_day_yields_nothing', 0, () => {
      const t = task(new Date(2026, 7, 8, 9, 0), new Date(2026, 7, 8, 11, 0));
      const segs = DaySegmenter.segmentsForDay(t, WallClock.minutes(new Date(2026, 7, 10)));
      expect(segs.length).assertEqual(0);
    });

    it('clipToRange_keeps_overnight_span_as_one_continuous_segment', 0, () => {
      const start = WallClock.minutes(new Date(2026, 7, 8, 22, 0));
      const end = WallClock.minutes(new Date(2026, 7, 9, 4, 30));
      const weekStart = WallClock.minutes(new Date(2026, 7, 8));
      const weekEnd = weekStart + WallClock.MINUTES_PER_DAY * 7;
      const segs = DaySegmenter.clipToRange('a', start, end, weekStart, weekEnd);
      expect(segs.length).assertEqual(1);
      expect(segs[0].start).assertEqual(start);
      expect(segs[0].end).assertEqual(end);
    });

    it('mergeAbutting_joins_midnight_split_into_one_bar', 0, () => {
      const midnight = WallClock.minutes(new Date(2026, 7, 9));
      const start = WallClock.minutes(new Date(2026, 7, 8, 18, 30));
      const end = WallClock.minutes(new Date(2026, 7, 9, 12, 45));
      const split = [
        new GanttSegment('a', start, midnight),
        new GanttSegment('a', midnight, end)
      ];
      const merged = DaySegmenter.mergeAbutting(split);
      expect(merged.length).assertEqual(1);
      expect(merged[0].start).assertEqual(start);
      expect(merged[0].end).assertEqual(end);
    });
  });
}
