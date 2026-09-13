import { describe, it, expect } from '@ohos/hypium';
import {
  bindDrawerCloser,
  consumeDrawerSystemBack,
  shouldDismissDrawerSwipe,
  sideDrawerWidthFor
} from '../../../main/ets/ui/common/SideDrawer';

export default function sideDrawerTest() {
  describe('SideDrawer', () => {
    it('width_clamps_to_360_480', 0, () => {
      expect(sideDrawerWidthFor(500)).assertEqual(360);
      expect(sideDrawerWidthFor(1000)).assertEqual(400);
      expect(sideDrawerWidthFor(2000)).assertEqual(480);
    });

    it('swipe_right_past_quarter_width_dismisses', 0, () => {
      expect(shouldDismissDrawerSwipe(99, 400)).assertFalse();
      expect(shouldDismissDrawerSwipe(100, 400)).assertTrue();
      expect(shouldDismissDrawerSwipe(-50, 400)).assertFalse();
      expect(shouldDismissDrawerSwipe(1, 0)).assertFalse();
    });

    it('system_back_calls_bound_closer_and_consumes', 0, () => {
      bindDrawerCloser(null);
      expect(consumeDrawerSystemBack()).assertFalse();
      let closed: number = 0;
      bindDrawerCloser(() => {
        closed = closed + 1;
      });
      expect(consumeDrawerSystemBack()).assertTrue();
      expect(closed).assertEqual(1);
      bindDrawerCloser(null);
      expect(consumeDrawerSystemBack()).assertFalse();
      expect(closed).assertEqual(1);
    });
  });
}
