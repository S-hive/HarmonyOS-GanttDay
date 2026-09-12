import smokeTest from './Smoke.test';
import wallClockTest from './WallClock.test';
import ganttGeometryTest from './GanttGeometry.test';
import daySegmenterTest from './DaySegmenter.test';
import laneLayoutTest from './LaneLayout.test';
import dayGestureMathTest from './DayGestureMath.test';

export default function testsuite() {
  smokeTest();
  wallClockTest();
  ganttGeometryTest();
  daySegmenterTest();
  laneLayoutTest();
  dayGestureMathTest();
}
