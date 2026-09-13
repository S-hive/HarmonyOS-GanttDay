import { describe, it, expect } from '@ohos/hypium';
import { persistOrToast, shouldToastSaveFailure } from '../../../main/ets/ui/common/SaveFailureToast';
import { EmptyTitleError } from '../../../main/ets/platform/TaskRepository';

export default function saveFailureToastTest() {
  describe('SaveFailureToast', () => {
    it('does_not_toast_empty_title', 0, () => {
      expect(shouldToastSaveFailure(new EmptyTitleError())).assertFalse();
    });

    it('toasts_other_rejects', 0, () => {
      expect(shouldToastSaveFailure(new Error('io'))).assertTrue();
    });

    it('persist_swallows_empty_title_without_toast', 0, async () => {
      let toasted: number = 0;
      await persistOrToast(Promise.reject(new EmptyTitleError()), () => {
        toasted++;
      });
      expect(toasted).assertEqual(0);
    });

    it('persist_toasts_other_rejects_and_does_not_throw', 0, async () => {
      let toasted: number = 0;
      await persistOrToast(Promise.reject(new Error('disk')), () => {
        toasted++;
      });
      expect(toasted).assertEqual(1);
    });
  });
}
