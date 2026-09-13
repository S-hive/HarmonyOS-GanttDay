import { describe, it, expect } from '@ohos/hypium';
import { MonthPlacedBar, MonthWeekLayout } from '../../../main/ets/domain/month/MonthSpanLayout';
import {
  MONTH_BAR_GAP,
  MONTH_BAR_H_GAP,
  MONTH_BAR_HEIGHT,
  MONTH_BAR_MIN_WIDTH,
  MONTH_DATE_ROW_HEIGHT,
  MONTH_HIT_BAR,
  MONTH_HIT_CELL,
  MONTH_HIT_NONE,
  MONTH_HIT_OVERFLOW,
  MONTH_OVERFLOW_HEIGHT,
  MonthHitResult,
  hitTestMonthWeek,
  monthBarLeft,
  monthBarTop,
  monthBarWidth,
  monthNeedsScroll,
  monthOpenDayFromHit,
  monthWeekRowHeights
} from '../../../main/ets/ui/month/MonthPage';

function daysFrom(monday: Date): Date[] {
  const days: Date[] = [];
  for (let i = 0; i < 7; i++) {
    days.push(new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + i));
  }
  return days;
}

function weekOf(
  monday: Date,
  bars: MonthPlacedBar[],
  overflowByDay: Map<number, number> = new Map<number, number>(),
  laneCount: number = 1
): MonthWeekLayout {
  return new MonthWeekLayout(monday, daysFrom(monday), bars, overflowByDay, laneCount);
}

function isSameDate(a: Date | null, b: Date): boolean {
  if (a === null) {
    return false;
  }
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

export default function monthPageTest() {
  describe('MonthPage', () => {
    const month: Date = new Date(2026, 7, 1);
    const weekWidth: number = 700;

    it('maps_start_end_frac_across_week_width', 0, () => {
      expect(monthBarLeft(2, weekWidth)).assertEqual(2 / 7 * weekWidth);
      expect(monthBarWidth(2, 3, weekWidth)).assertEqual((3 - 2) / 7 * weekWidth - MONTH_BAR_H_GAP);
    });

    it('leaves_1px_between_adjacent_bars', 0, () => {
      const right: number = monthBarLeft(2, weekWidth) + monthBarWidth(2, 3, weekWidth);
      expect(monthBarLeft(3, weekWidth) - right).assertEqual(MONTH_BAR_H_GAP);
    });

    it('enforces_min_bar_width_4vp', 0, () => {
      const raw: number = (0.01 - 0) / 7 * weekWidth;
      expect(raw < MONTH_BAR_MIN_WIDTH).assertEqual(true);
      expect(monthBarWidth(0, 0.01, weekWidth)).assertEqual(MONTH_BAR_MIN_WIDTH);
    });

    it('stacks_lanes_with_15vp_bar_and_2vp_gap', 0, () => {
      expect(MONTH_BAR_HEIGHT).assertEqual(15);
      expect(MONTH_BAR_GAP).assertEqual(2);
      expect(monthBarTop(0)).assertEqual(0);
      expect(monthBarTop(2)).assertEqual(2 * (MONTH_BAR_HEIGHT + MONTH_BAR_GAP));
    });

    it('bar_hit_uses_openDay_not_tap_column', 0, () => {
      const open: Date = new Date(2026, 7, 3);
      const bar: MonthPlacedBar = new MonthPlacedBar(
        'span',
        '跨日',
        0,
        0,
        4,
        open,
        0,
        1
      );
      const week: MonthWeekLayout = weekOf(new Date(2026, 7, 3), [bar]);
      const x: number = monthBarLeft(3, weekWidth) + 4;
      const y: number = MONTH_DATE_ROW_HEIGHT + 4;
      const hit: MonthHitResult = hitTestMonthWeek(week, month, weekWidth, x, y);
      expect(hit.kind).assertEqual(MONTH_HIT_BAR);
      expect(hit.taskId).assertEqual('span');
      expect(isSameDate(hit.openDay, open)).assertEqual(true);
      expect(isSameDate(monthOpenDayFromHit(hit), open)).assertEqual(true);
    });

    it('overflow_chip_opens_that_day', 0, () => {
      const overflow: Map<number, number> = new Map<number, number>();
      overflow.set(10, 2);
      const week: MonthWeekLayout = weekOf(new Date(2026, 7, 10), [], overflow, 1);
      const dayIndex: number = 0;
      const x: number = (dayIndex + 0.5) / 7 * weekWidth;
      const y: number = 8;
      const hit: MonthHitResult = hitTestMonthWeek(week, month, weekWidth, x, y);
      expect(hit.kind).assertEqual(MONTH_HIT_OVERFLOW);
      expect(isSameDate(hit.openDay, new Date(2026, 7, 10))).assertEqual(true);
    });

    it('in_month_cell_opens_that_day', 0, () => {
      const week: MonthWeekLayout = weekOf(new Date(2026, 7, 3), []);
      const x: number = 2.5 / 7 * weekWidth;
      const hit: MonthHitResult = hitTestMonthWeek(week, month, weekWidth, x, 6);
      expect(hit.kind).assertEqual(MONTH_HIT_CELL);
      expect(isSameDate(hit.openDay, new Date(2026, 7, 5))).assertEqual(true);
    });

    it('out_of_month_cell_is_not_tappable', 0, () => {
      const week: MonthWeekLayout = weekOf(new Date(2026, 6, 27), []);
      const x: number = 0.5 / 7 * weekWidth;
      const hit: MonthHitResult = hitTestMonthWeek(week, month, weekWidth, x, 6);
      expect(hit.kind).assertEqual(MONTH_HIT_NONE);
      expect(monthOpenDayFromHit(hit)).assertNull();
    });

    it('tiles_weeks_to_equal_viewport_height_when_content_fits', 0, () => {
      const heights: number[] = monthWeekRowHeights([40, 40, 40, 40, 40], 500);
      expect(heights.length).assertEqual(5);
      expect(heights[0]).assertEqual(100);
      expect(heights[4]).assertEqual(100);
      expect(monthNeedsScroll([40, 40, 40, 40, 40], 500)).assertEqual(false);
    });

    it('still_tiles_equal_height_when_a_week_content_is_taller', 0, () => {
      const mins: number[] = [40, 40, 180, 40, 40];
      const heights: number[] = monthWeekRowHeights(mins, 500);
      expect(heights[2]).assertEqual(100);
      expect(heights[0]).assertEqual(100);
    });

    it('hit_kind_is_never_delete', 0, () => {
      const bar: MonthPlacedBar = new MonthPlacedBar(
        'a',
        '拍摄',
        0,
        2,
        3,
        new Date(2026, 7, 5),
        0,
        1
      );
      const week: MonthWeekLayout = weekOf(new Date(2026, 7, 3), [bar]);
      const x: number = monthBarLeft(2, weekWidth) + 8;
      const y: number = MONTH_DATE_ROW_HEIGHT + 4;
      const hit: MonthHitResult = hitTestMonthWeek(week, month, weekWidth, x, y);
      expect(hit.kind === 'delete').assertEqual(false);
      expect(hit.kind).assertEqual(MONTH_HIT_BAR);
    });
  });
}
