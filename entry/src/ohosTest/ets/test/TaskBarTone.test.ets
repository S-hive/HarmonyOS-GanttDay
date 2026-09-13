import { describe, it, expect } from '@ohos/hypium';
import { taskBarArgb } from '../../../main/ets/domain/gantt/TaskBarTone';
import { AppColors } from '../../../main/ets/ui/theme/AppColors';

export default function taskBarToneTest() {
  describe('TaskBarTone', () => {
    it('done_is_always_azure_actual_shell', 0, () => {
      expect(taskBarArgb(true, 50, 200, 100)).assertEqual(AppColors.AZURE);
      expect(taskBarArgb(true, 50, 100, 100)).assertEqual(AppColors.AZURE);
      expect(taskBarArgb(true, 50, 100, 200)).assertEqual(AppColors.AZURE);
    });

    it('in_progress_incomplete_is_azure', 0, () => {
      expect(taskBarArgb(false, 50, 200, 100)).assertEqual(AppColors.AZURE);
    });

    it('incomplete_before_start_is_azure', 0, () => {
      expect(taskBarArgb(false, 150, 200, 100)).assertEqual(AppColors.AZURE);
      expect(taskBarArgb(false, 100, 200, 100)).assertEqual(AppColors.AZURE);
    });

    it('past_end_incomplete_is_gray', 0, () => {
      expect(taskBarArgb(false, 50, 100, 200)).assertEqual(AppColors.PLANNED_GRAY);
    });
  });
}
