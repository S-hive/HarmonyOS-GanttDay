import { describe, it, expect } from '@ohos/hypium';
import { TapClassifier, TapDecision, TapHit } from '../../../main/ets/domain/gesture/TapClassifier';

function hit(x: number, y: number, taskId: string | null): TapHit {
  const h = new TapHit();
  h.x = x;
  h.y = y;
  h.taskId = taskId;
  return h;
}

export default function tapClassifierTest() {
  describe('TapClassifier', () => {
    it('first_bar_tap_waits', 0, () => {
      const d = TapClassifier.onDown(null, 0, hit(10, 10, 'a'), 1000);
      expect(d).assertEqual(TapDecision.Wait);
    });

    it('second_bar_tap_same_task_waits', 0, () => {
      const d = TapClassifier.onDown(hit(10, 10, 'a'), 1000, hit(12, 11, 'a'), 1200);
      expect(d).assertEqual(TapDecision.Wait);
    });

    it('second_bar_tap_other_task_waits', 0, () => {
      const d = TapClassifier.onDown(hit(10, 10, 'a'), 1000, hit(80, 10, 'b'), 1200);
      expect(d).assertEqual(TapDecision.Wait);
    });

    it('second_empty_tap_does_not_create', 0, () => {
      const d = TapClassifier.onDown(hit(40, 40, null), 1000, hit(42, 41, null), 1200);
      expect(d).assertEqual(TapDecision.Ignore);
    });

    it('empty_second_tap_within_double_window_does_not_create', 0, () => {
      expect(TapClassifier.DOUBLE_MS).assertEqual(250);
      const d = TapClassifier.onDown(hit(40, 40, null), 1000, hit(42, 41, null), 1240);
      expect(d).assertEqual(TapDecision.Ignore);
    });

    it('timeout_on_bar_opens_form', 0, () => {
      expect(TapClassifier.onWaitTimeout(hit(10, 10, 'a'))).assertEqual(TapDecision.OpenForm);
    });

    it('timeout_on_empty_ignores', 0, () => {
      expect(TapClassifier.onWaitTimeout(hit(40, 40, null))).assertEqual(TapDecision.Ignore);
    });

    it('bar_release_opens_delete_veil_when_it_was_a_tap', 0, () => {
      expect(TapClassifier.shouldOpenDeleteVeilOnRelease('a', false, false, false)).assertTrue();
    });

    it('long_press_does_not_open_delete_veil', 0, () => {
      expect(TapClassifier.shouldOpenDeleteVeilOnRelease('a', false, false, true)).assertFalse();
    });

    it('actual_edit_does_not_open_delete_veil', 0, () => {
      expect(TapClassifier.shouldOpenDeleteVeilOnRelease('a', false, true, false)).assertFalse();
    });

    it('wait_timeout_while_press_held_does_not_open_veil', 0, () => {
      expect(TapClassifier.shouldOpenDeleteVeilOnWaitTimeout(true, true, false)).assertFalse();
      expect(TapClassifier.shouldOpenDeleteVeilOnWaitTimeout(false, false, false)).assertTrue();
    });

    it('same_task_far_apart_still_waits', 0, () => {
      const d = TapClassifier.onDown(hit(5, 5, 'night'), 1000, hit(200, 5, 'night'), 1180);
      expect(d).assertEqual(TapDecision.Wait);
    });

    it('empty_taps_far_apart_ignore', 0, () => {
      const d = TapClassifier.onDown(hit(0, 0, null), 1000, hit(80, 0, null), 1100);
      expect(d).assertEqual(TapDecision.Ignore);
    });

    it('empty_long_press_starts_create_drag', 0, () => {
      expect(TapClassifier.shouldStartCreateOnLongPress(null)).assertTrue();
    });

    it('bar_long_press_does_not_start_create_drag', 0, () => {
      expect(TapClassifier.shouldStartCreateOnLongPress('a')).assertFalse();
    });
  });
}
