import { Task } from '../domain/models/Task';

export class EmptyTitleError {
  message: string = 'title is empty';
}

export interface TaskListener {
  onTasks(tasks: Task[]): void;
}

export interface TaskRepository {
  watchOverlapping(rangeStart: number, rangeEnd: number, listener: TaskListener): () => void;
  getById(id: string): Promise<Task | null>;
  upsert(task: Task): Promise<void>;
  delete(id: string): Promise<void>;
}
