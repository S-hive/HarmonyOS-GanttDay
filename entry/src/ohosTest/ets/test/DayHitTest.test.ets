import { describe, it, expect } from '@ohos/hypium';
import {
  HIT_EMPTY,
  HIT_MOVE,
  HIT_RESIZE_END,
  HIT_RESIZE_START,
  HitBar,
  hitTest
} from '../../../main/ets/ui/day/DayHitTest';

function bar(
  id: string,
  x: number,
  y: number,
  w: number,
  h: number,
  trueStart: boolean = true,
  trueEnd: boolean = true
): HitBar {
  return new HitBar(id, x, y, w, h, trueStart, trueEnd);
}

export default function dayHitTestTest() {
  describe('DayHitTest', () => {
    const a: HitBar = bar('a', 100, 40, 80, 20);

    it('miss_returns_empty_and_null_task', 0, () => {
      const hit = hitTest([a], 10, 10, 8);
      expect(hit.taskId).assertNull();
      expect(hit.kind).assertEqual(HIT_EMPTY);
    });

    it('center_of_bar_is_move', 0, () => {
      const hit = hitTest([a], 140, 50, 8);
      expect(hit.taskId).assertEqual('a');
      expect(hit.kind).assertEqual(HIT_MOVE);
    });

    it('left_edge_hot_zone_is_resizeStart', 0, () => {
      const hit = hitTest([a], 100, 50, 8);
      expect(hit.taskId).assertEqual('a');
      expect(hit.kind).assertEqual(HIT_RESIZE_START);
    });

    it('right_edge_hot_zone_is_resizeEnd', 0, () => {
      const hit = hitTest([a], 180, 50, 8);
      expect(hit.taskId).assertEqual('a');
      expect(hit.kind).assertEqual(HIT_RESIZE_END);
    });

    it('slop_outside_left_edge_still_resizeStart', 0, () => {
      const hit = hitTest([a], 93, 50, 8);
      expect(hit.taskId).assertEqual('a');
      expect(hit.kind).assertEqual(HIT_RESIZE_START);
    });

    it('vertically_outside_bar_is_empty', 0, () => {
      const hit = hitTest([a], 140, 70, 8);
      expect(hit.taskId).assertNull();
      expect(hit.kind).assertEqual(HIT_EMPTY);
    });

    it('later_bar_wins_when_rects_overlap', 0, () => {
      const b: HitBar = bar('b', 130, 40, 80, 20);
      const hit = hitTest([a, b], 150, 50, 8);
      expect(hit.taskId).assertEqual('b');
      expect(hit.kind).assertEqual(HIT_MOVE);
    });

    it('default_edge_slop_is_8', 0, () => {
      const hit = hitTest([a], 92, 50);
      expect(hit.kind).assertEqual(HIT_RESIZE_START);
      const miss = hitTest([a], 91, 50);
      expect(miss.kind).assertEqual(HIT_EMPTY);
    });

    it('midnight_clip_right_edge_is_move', 0, () => {
      const overnight: HitBar = bar('ovn', 100, 40, 80, 20, true, false);
      const hit = hitTest([overnight], 180, 50, 8);
      expect(hit.taskId).assertEqual('ovn');
      expect(hit.kind).assertEqual(HIT_MOVE);
    });

    it('next_day_clip_left_edge_is_move', 0, () => {
      const nextDay: HitBar = bar('ovn', 100, 40, 80, 20, false, true);
      const hit = hitTest([nextDay], 100, 50, 8);
      expect(hit.taskId).assertEqual('ovn');
      expect(hit.kind).assertEqual(HIT_MOVE);
    });
  });
}
