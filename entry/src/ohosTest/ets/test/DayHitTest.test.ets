import { describe, it, expect } from '@ohos/hypium';
import {
  DAY_DRAG_START_SLOP,
  HIT_EMPTY,
  HIT_MOVE,
  HIT_RESIZE_END,
  HIT_RESIZE_START,
  HitBar,
  canvasXFromTouch,
  hitTest,
  laneIndexFromY,
  movementExceedsSlop,
  shouldCancelDoubleTapOnMove,
  snapshotTaskLanes
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

    it('maps_viewport_touch_to_canvas_x_with_scroll', 0, () => {
      expect(canvasXFromTouch(120, 400, 1400)).assertEqual(520);
    });

    it('keeps_canvas_local_touch_when_already_past_scroll', 0, () => {
      expect(canvasXFromTouch(580, 400, 1400)).assertEqual(580);
    });

    it('finger_jitter_under_32vp_does_not_start_drag', 0, () => {
      expect(DAY_DRAG_START_SLOP).assertEqual(32);
      expect(movementExceedsSlop(12, 8, 10, DAY_DRAG_START_SLOP)).assertEqual(false);
    });

    it('finger_move_over_32vp_starts_drag', 0, () => {
      expect(movementExceedsSlop(30, 20, 0, DAY_DRAG_START_SLOP)).assertEqual(true);
    });

    it('empty_first_tap_jitter_keeps_double_tap', 0, () => {
      expect(shouldCancelDoubleTapOnMove(null)).assertFalse();
    });

    it('bar_first_tap_move_cancels_double_tap', 0, () => {
      expect(shouldCancelDoubleTapOnMove('a')).assertTrue();
    });

    it('create_press_in_header_uses_lane_0', 0, () => {
      expect(laneIndexFromY(20, 33, 30)).assertEqual(0);
    });

    it('create_press_on_second_row_uses_lane_1', 0, () => {
      expect(laneIndexFromY(63, 33, 30)).assertEqual(1);
    });

    it('create_press_on_third_row_uses_lane_2', 0, () => {
      expect(laneIndexFromY(93, 33, 30)).assertEqual(2);
    });

    it('snapshot_keeps_each_bar_on_its_row', 0, () => {
      const lanes = snapshotTaskLanes([
        bar('a', 100, 35, 80, 26),
        bar('b', 200, 65, 80, 26)
      ], 33, 30);
      expect(lanes.get('a')).assertEqual(0);
      expect(lanes.get('b')).assertEqual(1);
    });
  });
}
