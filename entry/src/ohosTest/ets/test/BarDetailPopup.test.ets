import { describe, it, expect } from '@ohos/hypium';
import { WallClock } from '../../../main/ets/domain/time/WallClock';
import {
  BAR_DETAIL_ESTIMATED_H,
  BAR_DETAIL_GAP,
  BAR_DETAIL_MARGIN,
  barDetailPopupOrigin,
  formatBarHoverDate,
  formatBarHoverDetail,
  formatBarHoverMeta
} from '../../../main/ets/ui/common/BarDetailPopup';

export default function barDetailPopupTest() {
  describe('BarDetailPopup', () => {
    it('formats_compact_date_and_weekday', 0, () => {
      expect(formatBarHoverDate(new Date(2026, 7, 31))).assertEqual('8月31日(星期一)');
      expect(formatBarHoverDate(new Date(2026, 8, 6))).assertEqual('9月6日(星期日)');
    });

    it('formats_hover_meta_like_week_tooltip', 0, () => {
      const start: number = WallClock.minutes(new Date(2026, 7, 31, 9, 30));
      const end: number = WallClock.minutes(new Date(2026, 7, 31, 10, 30));
      expect(formatBarHoverMeta(start, end, new Date(2026, 7, 31)))
        .assertEqual('8月31日(星期一)·09:30 – 10:30 (1h)');
      expect(formatBarHoverDetail('团队周会', start, end, new Date(2026, 7, 31)))
        .assertEqual('团队周会\n8月31日(星期一)·09:30 – 10:30 (1h)');
    });

    it('sits_below_anchor_then_flips_and_clamps', 0, () => {
      const below = barDetailPopupOrigin(60, 80, 120, 800, 600, 220, BAR_DETAIL_ESTIMATED_H);
      expect(below.x).assertEqual(60);
      expect(below.y).assertEqual(120 + BAR_DETAIL_GAP);

      const flip = barDetailPopupOrigin(60, 500, 540, 800, 560, 220, BAR_DETAIL_ESTIMATED_H);
      expect(flip.y).assertEqual(500 - BAR_DETAIL_ESTIMATED_H - BAR_DETAIL_GAP);

      const clamp = barDetailPopupOrigin(700, 80, 120, 800, 600, 220, BAR_DETAIL_ESTIMATED_H);
      expect(clamp.x).assertEqual(800 - 220 - BAR_DETAIL_MARGIN);
    });
  });
}
