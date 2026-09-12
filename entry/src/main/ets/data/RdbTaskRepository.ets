import { relationalStore, ValuesBucket } from '@kit.ArkData';
import { FactorySwatches } from '../domain/gantt/FactorySwatches';
import { Task } from '../domain/models/Task';
import { EmptyTitleError, TaskListener, TaskRepository } from '../platform/TaskRepository';

class WatchSub {
  rangeStart: number;
  rangeEnd: number;
  listener: TaskListener;

  constructor(rangeStart: number, rangeEnd: number, listener: TaskListener) {
    this.rangeStart = rangeStart;
    this.rangeEnd = rangeEnd;
    this.listener = listener;
  }
}

export class RdbTaskRepository implements TaskRepository {
  store: relationalStore.RdbStore;
  subs: WatchSub[] = [];

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  watchOverlapping(rangeStart: number, rangeEnd: number, listener: TaskListener): () => void {
    const sub: WatchSub = new WatchSub(rangeStart, rangeEnd, listener);
    this.subs.push(sub);
    listener.onTasks(this.queryOverlapping(rangeStart, rangeEnd));
    return (): void => {
      const idx: number = this.subs.indexOf(sub);
      if (idx >= 0) {
        this.subs.splice(idx, 1);
      }
    };
  }

  getById(id: string): Promise<Task | null> {
    const rs: relationalStore.ResultSet = this.store.querySqlSync(
      'SELECT id, title, planned_start, planned_end, actual_start, actual_end, is_done, ' +
        'primary_tag_id, auto_swatch_id, override_swatch_id, notes, created_at ' +
        'FROM task WHERE id = ?',
      [id]
    );
    let found: Task | null = null;
    if (rs.goToFirstRow()) {
      found = this.taskFromRow(rs);
    }
    rs.close();
    return Promise.resolve(found);
  }

  async upsert(task: Task): Promise<void> {
    if (task.title.trim().length === 0) {
      return Promise.reject(new EmptyTitleError());
    }
    const stored: Task = this.normalize(task);
    const row: ValuesBucket = {
      'id': stored.id,
      'title': stored.title,
      'planned_start': stored.plannedStart,
      'planned_end': stored.plannedEnd,
      'actual_start': null,
      'actual_end': null,
      'is_done': 0,
      'primary_tag_id': stored.primaryTagId,
      'auto_swatch_id': FactorySwatches.DEFAULT_ID,
      'override_swatch_id': null,
      'notes': null,
      'created_at': stored.createdAt
    };
    await this.store.insert('task', row, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    this.notifyAll();
  }

  async delete(id: string): Promise<void> {
    await this.store.executeSql('DELETE FROM task_tag WHERE task_id = ?', [id]);
    await this.store.executeSql('DELETE FROM task WHERE id = ?', [id]);
    this.notifyAll();
  }

  normalize(task: Task): Task {
    let plannedEnd: number = task.plannedEnd;
    if (plannedEnd < task.plannedStart + 15) {
      plannedEnd = task.plannedStart + 15;
    }
    return new Task(
      task.id,
      task.title,
      task.plannedStart,
      plannedEnd,
      FactorySwatches.DEFAULT_ID,
      task.createdAt,
      null,
      null,
      false,
      task.primaryTagId,
      null,
      null
    );
  }

  queryOverlapping(rangeStart: number, rangeEnd: number): Task[] {
    const rs: relationalStore.ResultSet = this.store.querySqlSync(
      'SELECT id, title, planned_start, planned_end, actual_start, actual_end, is_done, ' +
        'primary_tag_id, auto_swatch_id, override_swatch_id, notes, created_at ' +
        'FROM task WHERE planned_start < ? AND planned_end > ? ORDER BY planned_start ASC',
      [rangeEnd, rangeStart]
    );
    const out: Task[] = [];
    if (rs.goToFirstRow()) {
      out.push(this.taskFromRow(rs));
      while (rs.goToNextRow()) {
        out.push(this.taskFromRow(rs));
      }
    }
    rs.close();
    return out;
  }

  notifyAll(): void {
    for (let i = 0; i < this.subs.length; i++) {
      const sub: WatchSub = this.subs[i];
      sub.listener.onTasks(this.queryOverlapping(sub.rangeStart, sub.rangeEnd));
    }
  }

  taskFromRow(rs: relationalStore.ResultSet): Task {
    const actualStart: number | null = rs.isColumnNull(rs.getColumnIndex('actual_start')) ?
      null : rs.getLong(rs.getColumnIndex('actual_start'));
    const actualEnd: number | null = rs.isColumnNull(rs.getColumnIndex('actual_end')) ?
      null : rs.getLong(rs.getColumnIndex('actual_end'));
    const primaryTagId: string | null = rs.isColumnNull(rs.getColumnIndex('primary_tag_id')) ?
      null : rs.getString(rs.getColumnIndex('primary_tag_id'));
    const overrideSwatchId: string | null = rs.isColumnNull(rs.getColumnIndex('override_swatch_id')) ?
      null : rs.getString(rs.getColumnIndex('override_swatch_id'));
    const notes: string | null = rs.isColumnNull(rs.getColumnIndex('notes')) ?
      null : rs.getString(rs.getColumnIndex('notes'));
    return new Task(
      rs.getString(rs.getColumnIndex('id')),
      rs.getString(rs.getColumnIndex('title')),
      rs.getLong(rs.getColumnIndex('planned_start')),
      rs.getLong(rs.getColumnIndex('planned_end')),
      rs.getString(rs.getColumnIndex('auto_swatch_id')),
      rs.getLong(rs.getColumnIndex('created_at')),
      actualStart,
      actualEnd,
      rs.getLong(rs.getColumnIndex('is_done')) !== 0,
      primaryTagId,
      overrideSwatchId,
      notes
    );
  }
}
