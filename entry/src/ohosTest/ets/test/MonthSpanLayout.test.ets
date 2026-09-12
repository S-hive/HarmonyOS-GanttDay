import { describe, it, expect } from '@ohos/hypium';
import {
  buildMonthWeekLayouts,
  DayTimeWindow,
  dayTimeWindowFor,
  MonthPlacedBar,
  MonthTaskSelection,
  MonthWeekLayout,
  selectVisibleMonthTasks
} from '../../../main/ets/domain/month/MonthSpanLayout';
import { Task } from '../../../main/ets/domain/models/Task';
import { WallClock } from '../../../main/ets/domain/time/WallClock';

function task(id: string, start: Date, end: Date, title: string = 't'): Task {
  return new Task(
    id,
    title,
    WallClock.minutes(start),
    WallClock.minutes(end),
    'azure',
    WallClock.minutes(start)
  );
}

function closeTo(actual: number, expected: number): boolean {
  return Math.abs(actual - expected) < 1e-9;
}

function isSameDate(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate();
}

function weekOn(weeks: MonthWeekLayout[], monday: Date): MonthWeekLayout {
  for (let i = 0; i < weeks.length; i++) {
    if (isSameDate(weeks[i].weekMonday, monday)) {
      return weeks[i];
    }
  }
  throw new Error(`week not found: ${monday.toString()}`);
}

function barById(bars: MonthPlacedBar[], id: string): MonthPlacedBar {
  for (let i = 0; i < bars.length; i++) {
    if (bars[i].taskId === id) {
      return bars[i];
    }
  }
  throw new Error(`bar not found: ${id}`);
}

export default function monthSpanLayoutTest() {
  describe('MonthSpanLayout', () => {
    const month: Date = new Date(2026, 7, 1);

    it('same_day_only_task_fills_its_day_cell', 0, () => {
      const t: Task = task('a', new Date(2026, 7, 5, 9), new Date(2026, 7, 5, 12), '拍摄');
      const weeks: MonthWeekLayout[] = buildMonthWeekLayouts(month, [t]);
      const week: MonthWeekLayout = weekOn(weeks, new Date(2026, 7, 3));
      expect(week.bars.length).assertEqual(1);
      const bar: MonthPlacedBar = week.bars[0];
      expect(closeTo(bar.startFrac, 2.0)).assertEqual(true);
      expect(closeTo(bar.endFrac, 3.0)).assertEqual(true);
      expect(bar.title).assertEqual('拍摄');
    });

    it('same_day_window_is_earliest_latest_and_bars_map_into_it', 0, () => {
      const tasks: Task[] = [
        task('early', new Date(2026, 7, 5, 9), new Date(2026, 7, 5, 10), '早'),
        task('late', new Date(2026, 7, 5, 16), new Date(2026, 7, 5, 17), '晚')
      ];
      const weeks: MonthWeekLayout[] = buildMonthWeekLayouts(month, tasks);
      const week: MonthWeekLayout = weekOn(weeks, new Date(2026, 7, 3));
      const early: MonthPlacedBar = barById(week.bars, 'early');
      const late: MonthPlacedBar = barById(week.bars, 'late');
      expect(closeTo(early.startFrac, 2 + 0 / 8)).assertEqual(true);
      expect(closeTo(early.endFrac, 2 + 1 / 8)).assertEqual(true);
      expect(closeTo(late.startFrac, 2 + 7 / 8)).assertEqual(true);
      expect(closeTo(late.endFrac, 2 + 8 / 8)).assertEqual(true);
    });

    it('cross_day_task_falls_back_to_0_24_when_no_same_day_tasks', 0, () => {
      const t: Task = task('b', new Date(2026, 7, 3, 0), new Date(2026, 7, 7, 0), '跑步');
      const weeks: MonthWeekLayout[] = buildMonthWeekLayouts(month, [t]);
      const week: MonthWeekLayout = weekOn(weeks, new Date(2026, 7, 3));
      expect(week.bars.length).assertEqual(1);
      expect(closeTo(week.bars[0].startFrac, 0.0)).assertEqual(true);
      expect(closeTo(week.bars[0].endFrac, 4.0)).assertEqual(true);
    });

    it('task_crossing_weeks_is_split_into_week_segments', 0, () => {
      const t: Task = task('c', new Date(2026, 7, 7, 18), new Date(2026, 7, 11, 10), '跨周');
      const weeks: MonthWeekLayout[] = buildMonthWeekLayouts(month, [t]);
      const w1: MonthWeekLayout = weekOn(weeks, new Date(2026, 7, 3));
      const w2: MonthWeekLayout = weekOn(weeks, new Date(2026, 7, 10));
      expect(w1.bars.length).assertEqual(1);
      expect(w2.bars.length).assertEqual(1);
      expect(closeTo(w1.bars[0].startFrac, 4 + 18 / 24)).assertEqual(true);
      expect(closeTo(w1.bars[0].endFrac, 7.0)).assertEqual(true);
      expect(closeTo(w2.bars[0].startFrac, 0.0)).assertEqual(true);
      expect(closeTo(w2.bars[0].endFrac, 1 + 10 / 24)).assertEqual(true);
    });

    it('keeps_at_most_10_tasks_per_day_and_reports_overflow', 0, () => {
      const tasks: Task[] = [];
      for (let i = 0; i < 12; i++) {
        tasks.push(task(`t${i}`, new Date(2026, 7, 10, i % 12), new Date(2026, 7, 10, i % 12 + 1), `T${i}`));
      }
      const selected: MonthTaskSelection = selectVisibleMonthTasks(month, tasks);
      expect(selected.visible.length).assertEqual(10);
      expect(selected.overflowByDay.get(10)).assertEqual(2);

      const weeks: MonthWeekLayout[] = buildMonthWeekLayouts(month, selected.visible, selected.overflowByDay);
      const week: MonthWeekLayout = weekOn(weeks, new Date(2026, 7, 10));
      expect(week.bars.length).assertEqual(10);
      expect(week.overflowByDay.get(10)).assertEqual(2);
    });

    it('end_exactly_at_midnight_is_exclusive_no_next_day_spill', 0, () => {
      const t: Task = task('d', new Date(2026, 7, 5, 22), new Date(2026, 7, 6, 0), '到午夜');
      const weeks: MonthWeekLayout[] = buildMonthWeekLayouts(month, [t]);
      const week: MonthWeekLayout = weekOn(weeks, new Date(2026, 7, 3));
      expect(week.bars.length).assertEqual(1);
      expect(closeTo(week.bars[0].startFrac, 2.0)).assertEqual(true);
      expect(closeTo(week.bars[0].endFrac, 3.0)).assertEqual(true);
    });

    it('dayTimeWindowFor_uses_same_day_earliest_and_latest_only', 0, () => {
      const day0: number = WallClock.minutes(new Date(2026, 7, 5));
      const win: DayTimeWindow = dayTimeWindowFor(day0, [
        task('a', new Date(2026, 7, 5, 10), new Date(2026, 7, 5, 11), 'a'),
        task('cross', new Date(2026, 7, 4, 20), new Date(2026, 7, 6, 8), 'cross'),
        task('b', new Date(2026, 7, 5, 14), new Date(2026, 7, 5, 16), 'b')
      ]);
      expect(win.start).assertEqual(WallClock.minutes(new Date(2026, 7, 5, 10)));
      expect(win.end).assertEqual(WallClock.minutes(new Date(2026, 7, 5, 16)));
    });
  });
}
