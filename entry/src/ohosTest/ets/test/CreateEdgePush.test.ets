import { describe, it, expect } from '@ohos/hypium';
import { WallClock } from '../../../main/ets/domain/time/WallClock';
import {
  CREATE_EDGE_HOLD_FRAC,
  CREATE_EDGE_REPEAT_MS,
  CREATE_EDGE_ZONE_VP,
  CreateEdgePush
} from '../../../main/ets/domain/gantt/CreateEdgePush';

export default function createEdgePushTest() {
  describe('CreateEdgePush', () => {
    const day0 = WallClock.minutes(new Date(2026, 7, 8));
    const viewStart = day0 + 8 * 60;
    const viewEnd = day0 + 22 * 60;
    const w = 700;

    it('constants_match_windows', 0, () => {
      expect(CREATE_EDGE_ZONE_VP).assertEqual(56);
      expect(CREATE_EDGE_REPEAT_MS).assertEqual(180);
      expect(CREATE_EDGE_HOLD_FRAC).assertEqual(0.35);
    });

    it('center_pointer_returns_null', 0, () => {
      const e = new CreateEdgePush();
      expect(e.applyPointer(350, w, viewStart, viewEnd, day0)).assertNull();
    });

    it('right_edge_opens_one_hour_from_fixed_base', 0, () => {
      const e = new CreateEdgePush();
      const p = e.applyPointer(w - 10, w, viewStart, viewEnd, day0);
      expect(p).assertEqual(viewEnd + 60);
    });

    it('second_frame_same_depth_does_not_runaway', 0, () => {
      const e = new CreateEdgePush();
      const a = e.applyPointer(w - 10, w, viewStart, viewEnd, day0);
      const b = e.applyPointer(w - 10, w, viewStart, viewEnd, day0);
      expect(a).assertEqual(b);
    });

    it('hold_repeat_only_on_outer_band', 0, () => {
      const e = new CreateEdgePush();
      expect(e.shouldHoldRepeat(w - 10, w)).assertTrue();
      expect(e.shouldHoldRepeat(w / 2, w)).assertFalse();
    });
  });
}
