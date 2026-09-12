import { describe, it, expect } from '@ohos/hypium';
import { LaneLayout } from '../../../main/ets/domain/gantt/LaneLayout';
import { GanttSegment } from '../../../main/ets/domain/models/GanttSegment';

export default function laneLayoutTest() {
  describe('LaneLayout', () => {
    it('non_overlapping_abutting_segments_share_lane_0', 0, () => {
      const a = new GanttSegment('1', 0, 60);
      const b = new GanttSegment('2', 60, 120);
      const lanes = LaneLayout.assign([a, b]);
      expect(lanes.get('1:0')).assertEqual(0);
      expect(lanes.get('2:60')).assertEqual(0);
    });

    it('partial_overlap_uses_distinct_lanes', 0, () => {
      const a = new GanttSegment('1', 0, 90);
      const b = new GanttSegment('2', 60, 120);
      const lanes = LaneLayout.assign([a, b]);
      expect(lanes.get('1:0') === lanes.get('2:60')).assertEqual(false);
    });

    it('full_overlap_uses_distinct_lanes', 0, () => {
      const a = new GanttSegment('1', 0, 60);
      const b = new GanttSegment('2', 0, 60);
      const lanes = LaneLayout.assign([a, b]);
      const pair = `${lanes.get('1:0')},${lanes.get('2:0')}`;
      expect(pair === '0,1' || pair === '1,0').assertEqual(true);
    });

    it('freed_lane_is_reused_after_earlier_segment_ends', 0, () => {
      const a = new GanttSegment('1', 0, 60);
      const b = new GanttSegment('2', 30, 90);
      const c = new GanttSegment('3', 60, 120);
      const lanes = LaneLayout.assign([a, b, c]);
      expect(lanes.get('1:0')).assertEqual(0);
      expect(lanes.get('2:30')).assertEqual(1);
      expect(lanes.get('3:60')).assertEqual(0);
    });

    it('laneCount_reports_max_lane_plus_1_and_1_for_empty', 0, () => {
      const a = new GanttSegment('1', 0, 60);
      const b = new GanttSegment('2', 0, 60);
      expect(LaneLayout.laneCount(LaneLayout.assign([a, b]))).assertEqual(2);
      expect(LaneLayout.laneCount(new Map<string, number>())).assertEqual(1);
    });
  });
}
