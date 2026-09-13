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

    it('exclusive_gives_each_task_its_own_lane', 0, () => {
      const a = new GanttSegment('1', 0, 60);
      const b = new GanttSegment('2', 60, 120);
      const lanes = LaneLayout.assignExclusive([a, b]);
      expect(lanes.get('1:0')).assertEqual(0);
      expect(lanes.get('2:60')).assertEqual(1);
    });

    it('exclusive_keeps_same_task_segments_on_one_lane', 0, () => {
      const first = new GanttSegment('night', 22 * 60, 24 * 60);
      const second = new GanttSegment('night', 24 * 60, 26 * 60);
      const other = new GanttSegment('day', 10 * 60, 11 * 60);
      const lanes = LaneLayout.assignExclusive([first, second, other]);
      expect(lanes.get('day:600')).assertEqual(0);
      expect(lanes.get('night:1320')).assertEqual(1);
      expect(lanes.get('night:1440')).assertEqual(1);
    });

    it('without_creating_task_keeps_existing_lanes', 0, () => {
      const a = new GanttSegment('1', 60, 120);
      const b = new GanttSegment('2', 180, 240);
      const draft = new GanttSegment('draft', 0, 90);
      const stable = LaneLayout.assign([a, b]);
      const duringCreate = LaneLayout.assign(LaneLayout.withoutTask([a, b, draft], 'draft'));
      expect(duringCreate.get('1:60')).assertEqual(stable.get('1:60'));
      expect(duringCreate.get('2:180')).assertEqual(stable.get('2:180'));
      expect(duringCreate.has('draft:0')).assertEqual(false);
    });

    it('next_free_lane_skips_occupied_preferred_row', 0, () => {
      const a = new GanttSegment('1', 0, 60);
      const b = new GanttSegment('2', 60, 120);
      const lanes = LaneLayout.assignExclusive([a, b]);
      expect(LaneLayout.nextFreeLane(lanes, 0)).assertEqual(2);
      expect(LaneLayout.nextFreeLane(lanes, 2)).assertEqual(2);
    });

    it('laneCount_reports_max_lane_plus_1_and_1_for_empty', 0, () => {
      const a = new GanttSegment('1', 0, 60);
      const b = new GanttSegment('2', 0, 60);
      expect(LaneLayout.laneCount(LaneLayout.assign([a, b]))).assertEqual(2);
      expect(LaneLayout.laneCount(new Map<string, number>())).assertEqual(1);
    });
  });
}
