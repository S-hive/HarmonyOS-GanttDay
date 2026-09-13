import { describe, it, expect } from '@ohos/hypium';
import {
  CREATE_POPUP_WIDTH,
  createPopupRect,
  formatBarCaption,
  formatBarTimeLabel,
  formatSpanDuration
} from '../../../main/ets/ui/day/CreateTaskPopup';

export default function createTaskPopupTest() {
  describe('CreateTaskPopup', () => {
    it('sits_below_anchor_and_clamps_to_8vp_margin', 0, () => {
      const rect = createPopupRect(40, 80, 120, 20, 800, 600);
      expect(rect.width).assertEqual(CREATE_POPUP_WIDTH);
      expect(rect.x).assertEqual(40);
      expect(rect.y).assertEqual(108);
    });

    it('flips_above_when_below_does_not_fit', 0, () => {
      const rect = createPopupRect(40, 500, 120, 20, 800, 560);
      expect(rect.y).assertEqual(500 - 128 - 8);
    });

    it('clamps_left_inside_screen_margin', 0, () => {
      const rect = createPopupRect(700, 80, 80, 20, 800, 600);
      expect(rect.x).assertEqual(800 - CREATE_POPUP_WIDTH - 8);
    });

    it('formats_start_end_and_duration', 0, () => {
      const start: number = 10 * 60 + 15;
      const end: number = 14 * 60 + 30;
      expect(formatSpanDuration(start, end)).assertEqual('4h 15m');
      expect(formatBarTimeLabel(start, end)).assertEqual('10:15 – 14:30 (4h 15m)');
    });

    it('formats_title_start_end_and_duration', 0, () => {
      const start: number = 9 * 60 + 15;
      const end: number = 10 * 60;
      expect(formatBarCaption('散步', start, end)).assertEqual('散步  09:15 – 10:00 (45m)');
      expect(formatBarCaption('  ', start, end)).assertEqual('09:15 – 10:00 (45m)');
    });
  });
}
