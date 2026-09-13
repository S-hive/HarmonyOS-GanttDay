import { describe, it, expect } from '@ohos/hypium';
import { MemoryTaskRepository } from '../../../main/ets/data/MemoryTaskRepository';
import { EmptyTitleError, TaskListener } from '../../../main/ets/platform/TaskRepository';
import { Task } from '../../../main/ets/domain/models/Task';
import { WallClock } from '../../../main/ets/domain/time/WallClock';

function overnight(): Task {
  return new Task(
    'night',
    'render video overnight',
    WallClock.minutes(new Date(2026, 7, 8, 23, 0)),
    WallClock.minutes(new Date(2026, 7, 9, 1, 0)),
    'azure',
    0
  );
}

class CollectingListener implements TaskListener {
  items: Task[] = [];

  onTasks(tasks: Task[]): void {
    this.items = tasks;
  }
}

function snapshot(repo: MemoryTaskRepository, rangeStart: number, rangeEnd: number): Task[] {
  const listener: CollectingListener = new CollectingListener();
  repo.watchOverlapping(rangeStart, rangeEnd, listener);
  return listener.items;
}

export default function memoryTaskRepositoryTest() {
  describe('MemoryTaskRepository', () => {
    it('overnight_visible_on_aug8_window', 0, async () => {
      const repo: MemoryTaskRepository = new MemoryTaskRepository();
      await repo.upsert(overnight());
      const start: number = WallClock.minutes(new Date(2026, 7, 8));
      const end: number = WallClock.minutes(new Date(2026, 7, 9));
      const seen: Task[] = snapshot(repo, start, end);
      expect(seen.length).assertEqual(1);
      expect(seen[0].id).assertEqual('night');
    });

    it('overnight_visible_on_aug9_window', 0, async () => {
      const repo: MemoryTaskRepository = new MemoryTaskRepository();
      await repo.upsert(overnight());
      const start: number = WallClock.minutes(new Date(2026, 7, 9));
      const end: number = WallClock.minutes(new Date(2026, 7, 10));
      const seen: Task[] = snapshot(repo, start, end);
      expect(seen.length).assertEqual(1);
      expect(seen[0].id).assertEqual('night');
    });

    it('overnight_hidden_on_aug10_window', 0, async () => {
      const repo: MemoryTaskRepository = new MemoryTaskRepository();
      await repo.upsert(overnight());
      const start: number = WallClock.minutes(new Date(2026, 7, 10));
      const end: number = WallClock.minutes(new Date(2026, 7, 11));
      const seen: Task[] = snapshot(repo, start, end);
      expect(seen.length).assertEqual(0);
    });

    it('watch_receives_list_after_upsert', 0, async () => {
      const repo: MemoryTaskRepository = new MemoryTaskRepository();
      const start: number = WallClock.minutes(new Date(2026, 7, 8));
      const end: number = WallClock.minutes(new Date(2026, 7, 9));
      const listener: CollectingListener = new CollectingListener();
      repo.watchOverlapping(start, end, listener);
      expect(listener.items.length).assertEqual(0);
      await repo.upsert(overnight());
      expect(listener.items.length).assertEqual(1);
      expect(listener.items[0].id).assertEqual('night');
    });

    it('delete_empties_watch_and_getById_is_null', 0, async () => {
      const repo: MemoryTaskRepository = new MemoryTaskRepository();
      await repo.upsert(overnight());
      const start: number = WallClock.minutes(new Date(2026, 7, 8));
      const end: number = WallClock.minutes(new Date(2026, 7, 9));
      const listener: CollectingListener = new CollectingListener();
      repo.watchOverlapping(start, end, listener);
      expect(listener.items.length).assertEqual(1);
      await repo.delete('night');
      expect(listener.items.length).assertEqual(0);
      const got: Task | null = await repo.getById('night');
      expect(got).assertNull();
    });

    it('complete_sets_actuals_and_uncomplete_clears_them', 0, async () => {
      const repo: MemoryTaskRepository = new MemoryTaskRepository();
      await repo.upsert(overnight());
      const start: number = overnight().plannedStart - 15;
      const end: number = overnight().plannedEnd + 15;
      await repo.complete('night', start, end);
      let got: Task | null = await repo.getById('night');
      expect(got === null).assertFalse();
      if (got !== null) {
        expect(got.isDone).assertTrue();
        expect(got.actualStart).assertEqual(start);
        expect(got.actualEnd).assertEqual(end);
      }
      await repo.uncomplete('night');
      got = await repo.getById('night');
      expect(got === null).assertFalse();
      if (got !== null) {
        expect(got.isDone).assertFalse();
        expect(got.actualStart).assertNull();
        expect(got.actualEnd).assertNull();
      }
    });

    it('upsert_empty_title_rejects', 0, async () => {
      const repo: MemoryTaskRepository = new MemoryTaskRepository();
      const start: number = WallClock.minutes(new Date(2026, 7, 8, 23, 0));
      const end: number = WallClock.minutes(new Date(2026, 7, 9, 1, 0));
      const empty: Task = new Task('empty', '', start, end, 'azure', 0);
      const blank: Task = new Task('blank', '   ', start, end, 'azure', 0);
      let emptyRejected: boolean = false;
      try {
        await repo.upsert(empty);
      } catch (e) {
        emptyRejected = e instanceof EmptyTitleError;
        if (e instanceof EmptyTitleError) {
          expect(e.message).assertEqual('title is empty');
        }
      }
      expect(emptyRejected).assertTrue();
      let blankRejected: boolean = false;
      try {
        await repo.upsert(blank);
      } catch (e) {
        blankRejected = e instanceof EmptyTitleError;
      }
      expect(blankRejected).assertTrue();
      const emptyGot: Task | null = await repo.getById('empty');
      const blankGot: Task | null = await repo.getById('blank');
      expect(emptyGot).assertNull();
      expect(blankGot).assertNull();
    });
  });
}
