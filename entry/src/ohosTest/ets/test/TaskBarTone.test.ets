import { describe, it, expect } from '@ohos/hypium';
import { FactorySwatches } from '../../../main/ets/domain/gantt/FactorySwatches';
import {
  resolvedSwatchArgb,
  taskBarArgb,
  taskBarArgbFromTask,
  taskBarLabelArgb
} from '../../../main/ets/domain/gantt/TaskBarTone';
import { Task } from '../../../main/ets/domain/models/Task';
import { AppColors } from '../../../main/ets/ui/theme/AppColors';

export default function taskBarToneTest() {
  describe('TaskBarTone', () => {
    const peach: number = 0xFFFFDAC1;

    it('unexpired_uses_original_swatch', 0, () => {
      expect(taskBarArgb(false, 50, 200, 100, peach)).assertEqual(peach);
      expect(taskBarArgb(false, 150, 200, 100, peach)).assertEqual(peach);
      expect(taskBarArgb(false, 100, 200, 100, peach)).assertEqual(peach);
    });

    it('expired_incomplete_is_gray', 0, () => {
      expect(taskBarArgb(false, 50, 100, 200, peach)).assertEqual(AppColors.PLANNED_GRAY);
    });

    it('done_keeps_original_swatch', 0, () => {
      expect(taskBarArgb(true, 50, 200, 100, peach)).assertEqual(peach);
      expect(taskBarArgb(true, 50, 100, 200, peach)).assertEqual(peach);
    });

    it('from_task_uses_override_then_auto', 0, () => {
      const autoOnly: Task = new Task('a', 'a', 50, 200, 'peach', 0);
      expect(resolvedSwatchArgb(autoOnly)).assertEqual(FactorySwatches.argbOf('peach'));
      expect(taskBarArgbFromTask(autoOnly, 100)).assertEqual(FactorySwatches.argbOf('peach'));

      const overridden: Task = new Task(
        'b',
        'b',
        50,
        200,
        'peach',
        0,
        null,
        null,
        false,
        null,
        'mint'
      );
      expect(resolvedSwatchArgb(overridden)).assertEqual(FactorySwatches.argbOf('mint'));
      expect(taskBarArgbFromTask(overridden, 100)).assertEqual(FactorySwatches.argbOf('mint'));
      expect(taskBarArgbFromTask(overridden, 300)).assertEqual(AppColors.PLANNED_GRAY);
    });

    it('label_is_dark_on_light_swatch_and_gray', 0, () => {
      expect(taskBarLabelArgb(peach)).assertEqual(0xDE000000);
      expect(taskBarLabelArgb(AppColors.PLANNED_GRAY)).assertEqual(0xDE000000);
      expect(taskBarLabelArgb(AppColors.AZURE)).assertEqual(0xFFFFFFFF);
    });
  });
}
