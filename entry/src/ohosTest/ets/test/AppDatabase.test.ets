import { describe, it, expect } from '@ohos/hypium';
import { Context } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { relationalStore, ValuesBucket } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import { AppDatabase, DatabaseOpenError } from '../../../main/ets/data/AppDatabase';
import { RdbTaskRepository } from '../../../main/ets/data/RdbTaskRepository';
import { TaskListener } from '../../../main/ets/platform/TaskRepository';
import { Task } from '../../../main/ets/domain/models/Task';
import { WallClock } from '../../../main/ets/domain/time/WallClock';

function testContext(): Context {
  return abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
}

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

function snapshot(repo: RdbTaskRepository, rangeStart: number, rangeEnd: number): Task[] {
  const listener: CollectingListener = new CollectingListener();
  repo.watchOverlapping(rangeStart, rangeEnd, listener);
  return listener.items;
}

function findById(tasks: Task[], id: string): Task | null {
  for (let i = 0; i < tasks.length; i++) {
    if (tasks[i].id === id) {
      return tasks[i];
    }
  }
  return null;
}

function writeGarbage(path: string): void {
  const file = fileIo.openSync(
    path,
    fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
  );
  fileIo.writeSync(file.fd, 'not-a-sqlite-database');
  fileIo.closeSync(file);
}

function listCorruptNames(dir: string): string[] {
  const names: string[] = fileIo.listFileSync(dir);
  const out: string[] = [];
  for (let i = 0; i < names.length; i++) {
    if (names[i].indexOf('gantday.db.corrupt-') === 0) {
      out.push(names[i]);
    }
  }
  return out;
}

export default function appDatabaseTest() {
  describe('AppDatabase', () => {
    it('open_insert_select_roundtrip', 0, async () => {
      const context: Context = testContext();
      const store: relationalStore.RdbStore = await AppDatabase.openOrRepair(context);
      const start: number = WallClock.minutes(new Date(2026, 7, 8, 9, 0));
      const end: number = WallClock.minutes(new Date(2026, 7, 8, 10, 0));
      const row: ValuesBucket = {
        'id': 'roundtrip',
        'title': 'shoot morning',
        'planned_start': start,
        'planned_end': end,
        'actual_start': null,
        'actual_end': null,
        'is_done': 0,
        'primary_tag_id': null,
        'auto_swatch_id': 'azure',
        'override_swatch_id': null,
        'notes': null,
        'created_at': 0
      };
      await store.insert('task', row);
      const rs: relationalStore.ResultSet = await store.querySql(
        'SELECT title, planned_start, planned_end FROM task WHERE id = ?',
        ['roundtrip']
      );
      expect(rs.goToFirstRow()).assertTrue();
      expect(rs.getString(rs.getColumnIndex('title'))).assertEqual('shoot morning');
      expect(rs.getLong(rs.getColumnIndex('planned_start'))).assertEqual(start);
      expect(rs.getLong(rs.getColumnIndex('planned_end'))).assertEqual(end);
      rs.close();
      await store.executeSql('DELETE FROM task WHERE id = ?', ['roundtrip']);
      await store.close();
    });

    it('overnight_visible_on_aug8_and_aug9_windows', 0, async () => {
      const context: Context = testContext();
      const store: relationalStore.RdbStore = await AppDatabase.openOrRepair(context);
      const repo: RdbTaskRepository = new RdbTaskRepository(store);
      await repo.upsert(overnight());
      const start8: number = WallClock.minutes(new Date(2026, 7, 8));
      const end8: number = WallClock.minutes(new Date(2026, 7, 9));
      const start9: number = WallClock.minutes(new Date(2026, 7, 9));
      const end9: number = WallClock.minutes(new Date(2026, 7, 10));
      const start10: number = WallClock.minutes(new Date(2026, 7, 10));
      const end10: number = WallClock.minutes(new Date(2026, 7, 11));
      const on8: Task[] = snapshot(repo, start8, end8);
      const on9: Task[] = snapshot(repo, start9, end9);
      const on10: Task[] = snapshot(repo, start10, end10);
      const night8: Task | null = findById(on8, 'night');
      const night9: Task | null = findById(on9, 'night');
      const night10: Task | null = findById(on10, 'night');
      expect(night8 !== null).assertTrue();
      expect(night8!.id).assertEqual('night');
      expect(night9 !== null).assertTrue();
      expect(night9!.id).assertEqual('night');
      expect(night10).assertNull();
      await repo.delete('night');
      await store.close();
    });

    it('corrupt_file_renamed_then_new_store_inserts', 0, async () => {
      const context: Context = testContext();
      const first: relationalStore.RdbStore = await AppDatabase.openOrRepair(context);
      await first.close();
      const dbPath: string = AppDatabase.databasePath(context);
      writeGarbage(dbPath);
      const before: number = listCorruptNames(AppDatabase.rdbDirectory(context)).length;
      let rejected: boolean = false;
      let backupPath: string = '';
      try {
        await AppDatabase.openOrRepair(context);
      } catch (e) {
        rejected = true;
        if (e instanceof DatabaseOpenError) {
          backupPath = e.path;
        }
      }
      expect(rejected).assertTrue();
      const afterNames: string[] = listCorruptNames(AppDatabase.rdbDirectory(context));
      expect(afterNames.length > before).assertTrue();
      expect(backupPath.indexOf(AppDatabase.CORRUPT_PREFIX) >= 0).assertTrue();
      const repaired: relationalStore.RdbStore = await AppDatabase.openOrRepair(context);
      const start: number = WallClock.minutes(new Date(2026, 7, 8, 11, 0));
      const end: number = WallClock.minutes(new Date(2026, 7, 8, 12, 0));
      const row: ValuesBucket = {
        'id': 'after-repair',
        'title': 'after repair',
        'planned_start': start,
        'planned_end': end,
        'actual_start': null,
        'actual_end': null,
        'is_done': 0,
        'primary_tag_id': null,
        'auto_swatch_id': 'azure',
        'override_swatch_id': null,
        'notes': null,
        'created_at': 0
      };
      await repaired.insert('task', row);
      const rs: relationalStore.ResultSet = await repaired.querySql(
        'SELECT title FROM task WHERE id = ?',
        ['after-repair']
      );
      expect(rs.goToFirstRow()).assertTrue();
      expect(rs.getString(rs.getColumnIndex('title'))).assertEqual('after repair');
      rs.close();
      await repaired.close();
    });
  });
}
