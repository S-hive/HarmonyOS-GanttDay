import smokeTest from './Smoke.test';
import wallClockTest from './WallClock.test';

export default function testsuite() {
  smokeTest();
  wallClockTest();
}
