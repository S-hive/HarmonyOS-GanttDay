import { describe, it, expect } from '@ohos/hypium';
import { sideDrawerWidthFor } from '../../../main/ets/ui/common/SideDrawer';

export default function sideDrawerTest() {
  describe('SideDrawer', () => {
    it('width_clamps_to_360_480', 0, () => {
      expect(sideDrawerWidthFor(500)).assertEqual(360);
      expect(sideDrawerWidthFor(1000)).assertEqual(400);
      expect(sideDrawerWidthFor(2000)).assertEqual(480);
    });
  });
}
