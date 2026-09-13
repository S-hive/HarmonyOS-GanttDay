import { describe, it, expect } from '@ohos/hypium';

export default function smokeTest() {
  describe('Smoke', () => {
    it('hypium_runs', 0, () => {
      expect(1 + 1).assertEqual(2);
    });
  });
}
