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

    it('second_bar_tap_same_task_deletes', 0, () => {
      const d = TapClassifier.onDown(hit(10, 10, 'a'), 1000, hit(12, 11, 'a'), 1200);
      expect(d).assertEqual(TapDecision.Delete);
    });

    it('second_bar_tap_other_task_waits', 0, () => {
      const d = TapClassifier.onDown(hit(10, 10, 'a'), 1000, hit(80, 10, 'b'), 1200);
      expect(d).assertEqual(TapDecision.Wait);
    });

    it('second_empty_tap_creates', 0, () => {
      const d = TapClassifier.onDown(hit(40, 40, null), 1000, hit(42, 41, null), 1200);
      expect(d).assertEqual(TapDecision.Create);
    });

    it('empty_second_tap_within_500ms_still_creates', 0, () => {
      expect(TapClassifier.DOUBLE_MS).assertEqual(500);
      const d = TapClassifier.onDown(hit(40, 40, null), 1000, hit(42, 41, null), 1450);
      expect(d).assertEqual(TapDecision.Create);
    });

    it('timeout_on_bar_opens_form', 0, () => {
      expect(TapClassifier.onWaitTimeout(hit(10, 10, 'a'))).assertEqual(TapDecision.OpenForm);
    });

    it('timeout_on_empty_ignores', 0, () => {
      expect(TapClassifier.onWaitTimeout(hit(40, 40, null))).assertEqual(TapDecision.Ignore);
    });

    it('same_task_far_apart_still_deletes', 0, () => {
      const d = TapClassifier.onDown(hit(5, 5, 'night'), 1000, hit(200, 5, 'night'), 1180);
      expect(d).assertEqual(TapDecision.Delete);
    });

    it('empty_taps_far_apart_ignore', 0, () => {
      const d = TapClassifier.onDown(hit(0, 0, null), 1000, hit(80, 0, null), 1100);
      expect(d).assertEqual(TapDecision.Ignore);
    });
  });
}
