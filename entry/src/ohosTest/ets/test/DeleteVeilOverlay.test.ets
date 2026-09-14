import { describe, it, expect } from '@ohos/hypium';
import {
  bindDeleteVeilCloser,
  consumeDeleteVeilBack,
  DELETE_VEIL_BOTTOM,
  DELETE_VEIL_TOP,
  isDeleteVeilTop
} from '../../../main/ets/ui/common/DeleteVeilOverlay';

export default function deleteVeilOverlayTest() {
  describe('DeleteVeilOverlay', () => {
    it('veil_colors_are_translucent_red_and_green', 0, () => {
      expect((DELETE_VEIL_TOP >>> 24) < 0xFF).assertTrue();
      expect((DELETE_VEIL_BOTTOM >>> 24) < 0xFF).assertTrue();
      expect(((DELETE_VEIL_TOP >> 16) & 0xFF) > ((DELETE_VEIL_TOP >> 8) & 0xFF)).assertTrue();
      expect(((DELETE_VEIL_BOTTOM >> 8) & 0xFF) > ((DELETE_VEIL_BOTTOM >> 16) & 0xFF)).assertTrue();
    });

    it('top_half_is_delete_bottom_half_is_restore', 0, () => {
      expect(isDeleteVeilTop(0, 100)).assertTrue();
      expect(isDeleteVeilTop(49.9, 100)).assertTrue();
      expect(isDeleteVeilTop(50, 100)).assertFalse();
      expect(isDeleteVeilTop(99, 100)).assertFalse();
    });

    it('system_back_cancels_bound_veil_and_consumes', 0, () => {
      bindDeleteVeilCloser(null);
      expect(consumeDeleteVeilBack()).assertFalse();
      let cancelled: number = 0;
      bindDeleteVeilCloser(() => {
        cancelled = cancelled + 1;
      });
      expect(consumeDeleteVeilBack()).assertTrue();
      expect(cancelled).assertEqual(1);
      bindDeleteVeilCloser(null);
      expect(consumeDeleteVeilBack()).assertFalse();
      expect(cancelled).assertEqual(1);
    });
  });
}
