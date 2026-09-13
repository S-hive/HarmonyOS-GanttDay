import { describe, it, expect } from '@ohos/hypium';
import { CreateStroke, END_CANCEL, END_POPUP } from '../../../main/ets/domain/gesture/CreateStroke';

export default function createStrokeTest() {
  describe('CreateStroke', () => {
    it('move_before_begin_is_ignored', 0, () => {
      const s = new CreateStroke();
      expect(s.move(80)).assertFalse();
      expect(s.isDragging()).assertFalse();
    });

    it('finish_under_4vp_cancels_and_does_not_rearm', 0, () => {
      const s = new CreateStroke();
      s.begin(40);
      s.move(42);
      expect(s.finish()).assertEqual(END_CANCEL);
      expect(s.isDragging()).assertFalse();
      expect(s.move(120)).assertFalse();
    });

    it('finish_at_least_4vp_opens_popup_and_keeps_xs', 0, () => {
      const s = new CreateStroke();
      s.begin(40);
      s.move(80);
      expect(s.x0()).assertEqual(40);
      expect(s.x1()).assertEqual(80);
      expect(s.finish()).assertEqual(END_POPUP);
      expect(s.x0()).assertEqual(40);
      expect(s.x1()).assertEqual(80);
      expect(s.isDragging()).assertFalse();
    });

    it('min_drag_constant_is_4', 0, () => {
      expect(CreateStroke.MIN_DRAG_VP).assertEqual(4);
    });
  });
}
