import smokeTest from './Smoke.test';
import wallClockTest from './WallClock.test';
import ganttGeometryTest from './GanttGeometry.test';

export default function testsuite() {
  smokeTest();
  wallClockTest();
  ganttGeometryTest();
}
