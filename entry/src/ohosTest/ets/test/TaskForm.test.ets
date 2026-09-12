import { describe, it, expect } from '@ohos/hypium';
import { Task } from '../../../main/ets/domain/models/Task';
import { taskAfterFormClose } from '../../../main/ets/ui/task/TaskForm';

function sample(): Task {
  return new Task('a', '拍摄', 100, 160, 'azure', 0);
}

export default function taskFormTest() {
  describe('TaskForm', () => {
    it('nonempty_title_upserts_title_and_times', 0, () => {
      const next: Task = taskAfterFormClose(sample(), '  新标题  ', 200, 260);
      expect(next.title).assertEqual('新标题');
      expect(next.plannedStart).assertEqual(200);
      expect(next.plannedEnd).assertEqual(260);
    });

    it('empty_title_keeps_title_and_saves_times', 0, () => {
      const next: Task = taskAfterFormClose(sample(), '   ', 300, 360);
      expect(next.title).assertEqual('拍摄');
      expect(next.plannedStart).assertEqual(300);
      expect(next.plannedEnd).assertEqual(360);
    });
  });
}
