import { describe, it, expect } from '@ohos/hypium';
import {
  actualEditBannerText,
  actualEditLanePair,
  dayBarSpanEnd,
  dayBarSpanStart,
  dayBarUsesActual,
  plannedInnerStrip
} from '../../../main/ets/domain/gantt/ActualEdit';
import { Task } from '../../../main/ets/domain/models/Task';

export default function actualEditTest() {
  describe('ActualEdit', () => {
    it('prefers_actual_below_planned_when_room', 0, () => {
      const lanes = actualEditLanePair(2, true, 8);
      expect(lanes.planned).assertEqual(2);
      expect(lanes.actual).assertEqual(3);
    });

    it('places_actual_above_when_no_room_below', 0, () => {
      const lanes = actualEditLanePair(7, true, 8);
      expect(lanes.planned).assertEqual(7);
      expect(lanes.actual).assertEqual(6);
    });

    it('swaps_when_planned_is_top_and_no_room_below', 0, () => {
      const lanes = actualEditLanePair(0, true, 1);
      expect(lanes.planned).assertEqual(1);
      expect(lanes.actual).assertEqual(0);
    });

    it('completed_day_bar_uses_actual_span', 0, () => {
      const done: Task = new Task('a', '跑', 100, 160, 'azure', 0, 80, 200, true);
      expect(dayBarUsesActual(done, false)).assertTrue();
      expect(dayBarSpanStart(done, false)).assertEqual(80);
      expect(dayBarSpanEnd(done, false)).assertEqual(200);
      expect(dayBarUsesActual(done, true)).assertFalse();
      expect(dayBarSpanStart(done, true)).assertEqual(100);
    });

    it('planned_strip_sits_at_bottom_of_actual_bar', 0, () => {
      const strip = plannedInnerStrip(100, 40, 200, 20, 80, 120);
      expect(strip.y).assertEqual(40 + 20 - strip.height);
      expect(strip.height > 0).assertTrue();
      expect(strip.x).assertEqual(80);
      expect(strip.width).assertEqual(120);
    });

    it('banner_mentions_uncomplete_only_when_done', 0, () => {
      expect(actualEditBannerText('晨跑 5 公里', false))
        .assertEqual('设置实际时间：晨跑 5 公里　·　可在任意行长按拖拽　·　返回退出');
      expect(actualEditBannerText('晨跑 5 公里', true))
        .assertEqual('设置实际时间：晨跑 5 公里　·　可在任意行长按拖拽　·　长按实际条取消完成　·　返回退出');
    });
  });
}
