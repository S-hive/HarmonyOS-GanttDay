export class Task {
  id: string;
  title: string;
  plannedStart: number;
  plannedEnd: number;
  actualStart: number | null;
  actualEnd: number | null;
  isDone: boolean;
  primaryTagId: string | null;
  autoSwatchId: string;
  overrideSwatchId: string | null;
  notes: string | null;
  createdAt: number;

  constructor(
    id: string,
    title: string,
    plannedStart: number,
    plannedEnd: number,
    autoSwatchId: string,
    createdAt: number,
    actualStart: number | null = null,
    actualEnd: number | null = null,
    isDone: boolean = false,
    primaryTagId: string | null = null,
    overrideSwatchId: string | null = null,
    notes: string | null = null
  ) {
    this.id = id;
    this.title = title;
    this.plannedStart = plannedStart;
    this.plannedEnd = plannedEnd;
    this.actualStart = actualStart;
    this.actualEnd = actualEnd;
    this.isDone = isDone;
    this.primaryTagId = primaryTagId;
    this.autoSwatchId = autoSwatchId;
    this.overrideSwatchId = overrideSwatchId;
    this.notes = notes;
    this.createdAt = createdAt;
  }

  copyWith(
    title?: string,
    plannedStart?: number,
    plannedEnd?: number,
    actualStart?: number | null,
    actualEnd?: number | null,
    isDone?: boolean,
    primaryTagId?: string | null,
    overrideSwatchId?: string | null,
    notes?: string | null,
    clearActuals: boolean = false,
    clearPrimaryTag: boolean = false,
    clearOverrideSwatch: boolean = false,
    clearNotes: boolean = false
  ): Task {
    return new Task(
      this.id,
      title !== undefined ? title : this.title,
      plannedStart !== undefined ? plannedStart : this.plannedStart,
      plannedEnd !== undefined ? plannedEnd : this.plannedEnd,
      this.autoSwatchId,
      this.createdAt,
      clearActuals ? null : (actualStart !== undefined ? actualStart : this.actualStart),
      clearActuals ? null : (actualEnd !== undefined ? actualEnd : this.actualEnd),
      isDone !== undefined ? isDone : this.isDone,
      clearPrimaryTag ? null : (primaryTagId !== undefined ? primaryTagId : this.primaryTagId),
      clearOverrideSwatch ? null :
        (overrideSwatchId !== undefined ? overrideSwatchId : this.overrideSwatchId),
      clearNotes ? null : (notes !== undefined ? notes : this.notes)
    );
  }
}
