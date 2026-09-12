import { describe, it, expect } from '@ohos/hypium';
import { WeekSlot } from '../../../main/ets/domain/week/WeekColumnLayout';
import {
  WEEK_DAY_BOUNDARY_STRIDE,
  WEEK_HOUR_HEIGHT,
  hitTestWeekBlock,
  weekBlockRect,
  weekDayLeft,
  weekDayWidth,
  weekDefaultScrollY,
  weekScrollY
} from '../../../main/ets/ui/week/WeekPage';

function slot(
  id: string,
  dayIndex: number,
  topFrac: number,
  heightFrac: number,
  columnIndex: number = 0,
  columnCount: number = 1
): WeekSlot {
  return new WeekSlot(id, id, dayIndex, 0, 0, 0, 0, topFrac, heightFrac, columnIndex, columnCount);
}

export default function weekPageTest() {
  describe('WeekPage', () => {
    it('maps_frac_to_48vp_hour_rows', 0, () => {
      const r = weekBlockRect(slot('a', 0, 8 / 24, 2 / 24), 100);
      expect(r.y).assertEqual(8 * WEEK_HOUR_HEIGHT);
      expect(r.height).assertEqual(2 * WEEK_HOUR_HEIGHT);
      expect(r.x).assertEqual(0);
      expect(r.width).assertEqual(100);
    });

    it('splits_overlap_columns_evenly', 0, () => {
      const left = weekBlockRect(slot('a', 0, 0.5, 0.1, 0, 2), 100);
      const right = weekBlockRect(slot('b', 0, 0.5, 0.1, 1, 2), 100);
      expect(left.x).assertEqual(0);
      expect(left.width).assertEqual(50);
      expect(right.x).assertEqual(50);
      expect(right.width).assertEqual(50);
    });

    it('offsets_later_days_by_boundary_stride', 0, () => {
      const dayWidth: number = weekDayWidth(7 * 100 + 6 * WEEK_DAY_BOUNDARY_STRIDE);
      expect(dayWidth).assertEqual(100);
      expect(weekDayLeft(2, 100)).assertEqual(2 * (100 + WEEK_DAY_BOUNDARY_STRIDE));
      const r = weekBlockRect(slot('c', 2, 0, 1), 100);
      expect(r.x).assertEqual(2 * (100 + WEEK_DAY_BOUNDARY_STRIDE));
    });

    it('default_scroll_is_8am', 0, () => {
      expect(weekDefaultScrollY()).assertEqual(8 * WEEK_HOUR_HEIGHT);
      expect(weekScrollY(2000)).assertEqual(0);
      expect(weekScrollY(400)).assertEqual(8 * WEEK_HOUR_HEIGHT);
    });

    it('hit_test_later_block_wins', 0, () => {
      const a = weekBlockRect(slot('a', 0, 0, 1), 100);
      const b = weekBlockRect(slot('b', 0, 0, 1, 0, 1), 100);
      expect(hitTestWeekBlock([a, b], 10, 10)).assertEqual('b');
      expect(hitTestWeekBlock([a], 200, 10)).assertNull();
    });
  });
}
