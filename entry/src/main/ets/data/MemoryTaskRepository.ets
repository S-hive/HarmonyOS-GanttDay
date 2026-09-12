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

export class MemoryTaskRepository implements TaskRepository {
  tasks: Task[] = [];
  subs: WatchSub[] = [];

  watchOverlapping(rangeStart: number, rangeEnd: number, listener: TaskListener): () => void {
    const sub: WatchSub = new WatchSub(rangeStart, rangeEnd, listener);
    this.subs.push(sub);
    listener.onTasks(this.overlapping(rangeStart, rangeEnd));
    return (): void => {
      const idx: number = this.subs.indexOf(sub);
      if (idx >= 0) {
        this.subs.splice(idx, 1);
      }
    };
  }

  getById(id: string): Promise<Task | null> {
    return Promise.resolve(this.findById(id));
  }

  upsert(task: Task): Promise<void> {
    if (task.title.trim().length === 0) {
      return Promise.reject(new EmptyTitleError());
    }
    const stored: Task = this.normalize(task);
    const idx: number = this.indexOfId(stored.id);
    if (idx >= 0) {
      this.tasks[idx] = stored;
    } else {
      this.tasks.push(stored);
    }
    this.notifyAll();
    return Promise.resolve();
  }

  delete(id: string): Promise<void> {
    const kept: Task[] = [];
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].id !== id) {
        kept.push(this.tasks[i]);
      }
    }
    this.tasks = kept;
    this.notifyAll();
    return Promise.resolve();
  }

  normalize(task: Task): Task {
    let plannedEnd: number = task.plannedEnd;
    if (plannedEnd < task.plannedStart + 15) {
      plannedEnd = task.plannedStart + 15;
    }
    const autoSwatchId: string = task.autoSwatchId.length === 0 ?
      FactorySwatches.DEFAULT_ID : task.autoSwatchId;
    return new Task(
      task.id,
      task.title,
      task.plannedStart,
      plannedEnd,
      autoSwatchId,
      task.createdAt,
      task.actualStart,
      task.actualEnd,
      task.isDone,
      task.primaryTagId,
      task.overrideSwatchId,
      task.notes
    );
  }

  overlapping(rangeStart: number, rangeEnd: number): Task[] {
    const out: Task[] = [];
    for (let i = 0; i < this.tasks.length; i++) {
      const t: Task = this.tasks[i];
      if (t.plannedStart < rangeEnd && t.plannedEnd > rangeStart) {
        out.push(t);
      }
    }
    return out;
  }

  notifyAll(): void {
    for (let i = 0; i < this.subs.length; i++) {
      const sub: WatchSub = this.subs[i];
      sub.listener.onTasks(this.overlapping(sub.rangeStart, sub.rangeEnd));
    }
  }

  findById(id: string): Task | null {
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].id === id) {
        return this.tasks[i];
      }
    }
    return null;
  }

  indexOfId(id: string): number {
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].id === id) {
        return i;
      }
    }
    return -1;
  }
}
