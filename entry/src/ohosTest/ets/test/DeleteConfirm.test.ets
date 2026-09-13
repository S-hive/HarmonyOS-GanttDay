import { describe, it, expect } from '@ohos/hypium';
import { deleteConfirmMessage } from '../../../main/ets/ui/common/DeleteConfirm';

export default function deleteConfirmTest() {
  describe('DeleteConfirm', () => {
    it('message_includes_title_and_irreversible_note', 0, () => {
      expect(deleteConfirmMessage('拍摄')).assertEqual('删除「拍摄」？此操作无法撤销。');
    });
  });
}
