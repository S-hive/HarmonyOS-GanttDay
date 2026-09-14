import { MemoryTaskRepository } from '../../data/MemoryTaskRepository';
import { taskBarArgbFromTask, taskBarLabelArgb } from '../../domain/gantt/TaskBarTone';
import {
  MonthPlacedBar,
  MonthTaskSelection,
  MonthWeekLayout,
  buildMonthWeekLayouts,
  selectVisibleMonthTasks
} from '../../domain/month/MonthSpanLayout';
import { Task } from '../../domain/models/Task';
import { dateOnly, mondayOnOrBefore } from '../../domain/time/Calendar';
import { WallClock } from '../../domain/time/WallClock';
import { TaskListener, TaskRepository } from '../../platform/TaskRepository';
import { AppColors } from '../theme/AppColors';

export const MONTH_BAR_HEIGHT: number = 15;
export const MONTH_BAR_GAP: number = 2;
export const MONTH_BAR_H_GAP: number = 1;
export const MONTH_BAR_MIN_WIDTH: number = 4;
export const MONTH_DATE_ROW_HEIGHT: number = 28;
export const MONTH_OVERFLOW_HEIGHT: number = 16;
export const MONTH_WEEKDAY_ROW_HEIGHT: number = 24;

export const MONTH_HIT_NONE: string = 'none';
export const MONTH_HIT_BAR: string = 'bar';
export const MONTH_HIT_OVERFLOW: string = 'overflow';
export const MONTH_HIT_CELL: string = 'cell';

const WEEKDAY_LABELS: string[] = ['一', '二', '三', '四', '五', '六', '日'];

export class MonthHitResult {
  kind: string;
  openDay: Date | null;
  taskId: string | null;

  constructor(kind: string, openDay: Date | null, taskId: string | null) {
    this.kind = kind;
    this.openDay = openDay;
    this.taskId = taskId;
  }
}

class PageTaskSink implements TaskListener {
  apply: (tasks: Task[]) => void = (_tasks: Task[]): void => {
  };

  onTasks(tasks: Task[]): void {
    this.apply(tasks);
  }
}

export function monthBarLeft(startFrac: number, weekWidth: number): number {
  return startFrac / 7 * weekWidth;
}

export function monthBarWidth(startFrac: number, endFrac: number, weekWidth: number): number {
  const w: number = (endFrac - startFrac) / 7 * weekWidth - MONTH_BAR_H_GAP;
  if (w < MONTH_BAR_MIN_WIDTH) {
    return MONTH_BAR_MIN_WIDTH;
  }
  return w;
}

export function monthBarTop(lane: number): number {
  return lane * (MONTH_BAR_HEIGHT + MONTH_BAR_GAP);
}

export function monthNeedsScroll(minHeights: number[], viewportHeight: number): boolean {
  const n: number = minHeights.length;
  if (n === 0 || viewportHeight <= 0) {
    return false;
  }
  const equal: number = viewportHeight / n;
  for (let i = 0; i < n; i++) {
    if (minHeights[i] > equal + 0.5) {
      return true;
    }
  }
  return false;
}

export function monthWeekRowHeights(minHeights: number[], viewportHeight: number): number[] {
  const n: number = minHeights.length;
  if (n === 0) {
    return [];
  }
  if (viewportHeight <= 0) {
    return minHeights.slice();
  }
  const equal: number = viewportHeight / n;
  const out: number[] = [];
  for (let i = 0; i < n; i++) {
    out.push(equal);
  }
  return out;
}

export function monthBarAreaHeight(laneCount: number, hasOverflow: boolean): number {
  let lanes: number = laneCount;
  if (lanes < 1) {
    lanes = 1;
  }
  let h: number = lanes * (MONTH_BAR_HEIGHT + MONTH_BAR_GAP);
  if (hasOverflow) {
    h += MONTH_OVERFLOW_HEIGHT;
  }
  return h;
}

export function monthDayIndexAtX(x: number, weekWidth: number): number {
  if (weekWidth <= 0) {
    return 0;
  }
  let i: number = Math.floor(x / weekWidth * 7);
  if (i < 0) {
    return 0;
  }
  if (i > 6) {
    return 6;
  }
  return i;
}

export function isMonthGridDay(day: Date, month: Date): boolean {
  return day.getFullYear() === month.getFullYear() && day.getMonth() === month.getMonth();
}

export function weekHasOverflow(week: MonthWeekLayout): boolean {
  let found: boolean = false;
  week.overflowByDay.forEach((n: number) => {
    if (n > 0) {
      found = true;
    }
  });
  return found;
}

export function monthOpenDayFromHit(hit: MonthHitResult): Date | null {
  if (hit.kind === MONTH_HIT_NONE) {
    return null;
  }
  return hit.openDay;
}

function overflowCount(week: MonthWeekLayout, day: Date): number {
  const n: number | undefined = week.overflowByDay.get(day.getDate());
  if (n === undefined) {
    return 0;
  }
  return n;
}

export function hitTestMonthWeek(
  week: MonthWeekLayout,
  month: Date,
  weekWidth: number,
  x: number,
  y: number
): MonthHitResult {
  const dayIndex: number = monthDayIndexAtX(x, weekWidth);
  const day: Date = week.days[dayIndex];
  const inMonth: boolean = isMonthGridDay(day, month);
  const n: number = overflowCount(week, day);
  if (y < MONTH_DATE_ROW_HEIGHT) {
    if (!inMonth) {
      return new MonthHitResult(MONTH_HIT_NONE, null, null);
    }
    if (n > 0) {
      return new MonthHitResult(MONTH_HIT_OVERFLOW, dateOnly(day), null);
    }
    return new MonthHitResult(MONTH_HIT_CELL, dateOnly(day), null);
  }
  const localY: number = y - MONTH_DATE_ROW_HEIGHT;
  for (let i = week.bars.length - 1; i >= 0; i--) {
    const bar: MonthPlacedBar = week.bars[i];
    const left: number = monthBarLeft(bar.startFrac, weekWidth);
    const width: number = monthBarWidth(bar.startFrac, bar.endFrac, weekWidth);
    const top: number = monthBarTop(bar.lane);
    if (x >= left && x <= left + width && localY >= top && localY <= top + MONTH_BAR_HEIGHT) {
      return new MonthHitResult(MONTH_HIT_BAR, dateOnly(bar.openDay), bar.taskId);
    }
  }
  if (inMonth && n > 0) {
    const overflowTop: number = monthBarAreaHeight(week.laneCount, true) - MONTH_OVERFLOW_HEIGHT;
    if (localY >= overflowTop) {
      return new MonthHitResult(MONTH_HIT_OVERFLOW, dateOnly(day), null);
    }
  }
  if (!inMonth) {
    return new MonthHitResult(MONTH_HIT_NONE, null, null);
  }
  return new MonthHitResult(MONTH_HIT_CELL, dateOnly(day), null);
}

function sameCalendarDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function lengthVp(value: Length): number {
  return parseFloat(`${value}`);
}

@Component
export struct MonthPage {
  repo: TaskRepository = new MemoryTaskRepository();
  @Prop date: Date = new Date();
  onOpenDay: (day: Date) => void = (_day: Date): void => {
  };
  @State weekWidthVp: number = 700;
  @State bodyHeightVp: number = 600;
  @State cachedTasks: Task[] = [];

  private sink: PageTaskSink = new PageTaskSink();
  private unwatch: () => void = (): void => {
  };
  private boundMonthKey: string = '';

  aboutToAppear(): void {
    this.sink.apply = (list: Task[]): void => {
      this.cachedTasks = list;
    };
    this.bindWatch();
  }

  aboutToUpdate(): void {
    const key: string = this.monthKey();
    if (key !== this.boundMonthKey) {
      this.bindWatch();
    }
  }

  aboutToDisappear(): void {
    this.unwatch();
    this.unwatch = (): void => {
    };
    this.boundMonthKey = '';
  }

  private monthAnchor(): Date {
    return new Date(this.date.getFullYear(), this.date.getMonth(), 1);
  }

  private monthKey(): string {
    return `${this.date.getFullYear()}-${this.date.getMonth()}`;
  }

  private bindWatch(): void {
    this.unwatch();
    const month: Date = this.monthAnchor();
    const monthEnd: Date = new Date(month.getFullYear(), month.getMonth() + 1, 1);
    const firstMonday: Date = mondayOnOrBefore(month);
    const lastDay: Date = new Date(monthEnd.getFullYear(), monthEnd.getMonth(), monthEnd.getDate() - 1);
    const lastMonday: Date = mondayOnOrBefore(lastDay);
    const rangeStart: number = WallClock.minutes(firstMonday);
    const rangeEnd: number = WallClock.minutes(lastMonday) + 7 * WallClock.MINUTES_PER_DAY;
    this.boundMonthKey = this.monthKey();
    this.unwatch = this.repo.watchOverlapping(rangeStart, rangeEnd, this.sink);
  }

  private layouts(): MonthWeekLayout[] {
    const month: Date = this.monthAnchor();
    const selected: MonthTaskSelection = selectVisibleMonthTasks(month, this.cachedTasks);
    return buildMonthWeekLayouts(month, selected.visible, selected.overflowByDay);
  }

  private applyWidth(width: number): void {
    if (width <= 0) {
      return;
    }
    this.weekWidthVp = width;
  }

  private applyBody(width: number, height: number): void {
    this.applyWidth(width);
    if (height > 0) {
      this.bodyHeightVp = height;
    }
  }

  private minWeekHeights(weeks: MonthWeekLayout[]): number[] {
    const out: number[] = [];
    for (let i = 0; i < weeks.length; i++) {
      out.push(this.weekBodyHeight(weeks[i]));
    }
    return out;
  }

  private weekTileHeight(): number {
    const weeks: MonthWeekLayout[] = this.layouts();
    const heights: number[] = monthWeekRowHeights(this.minWeekHeights(weeks), this.bodyHeightVp);
    if (heights.length === 0) {
      return 0;
    }
    return heights[0];
  }

  private cellOverflow(week: MonthWeekLayout, day: Date): number {
    if (!isMonthGridDay(day, this.monthAnchor())) {
      return 0;
    }
    return overflowCount(week, day);
  }

  private findTask(id: string): Task | null {
    for (let i = 0; i < this.cachedTasks.length; i++) {
      if (this.cachedTasks[i].id === id) {
        return this.cachedTasks[i];
      }
    }
    return null;
  }

  private barColor(taskId: string): number {
    const task: Task | null = this.findTask(taskId);
    if (task === null) {
      return AppColors.AZURE;
    }
    return taskBarArgbFromTask(task, WallClock.minutes(new Date()));
  }

  private dateLabel(day: Date): string {
    if (!isMonthGridDay(day, this.monthAnchor())) {
      return '';
    }
    return `${day.getDate()}`;
  }

  private cellBackground(day: Date): number {
    if (isMonthGridDay(day, this.monthAnchor()) && sameCalendarDay(day, new Date())) {
      return 0x0F6198F6;
    }
    return AppColors.BAR_BACKGROUND;
  }

  private openFromHit(week: MonthWeekLayout, x: number, y: number): void {
    const hit: MonthHitResult = hitTestMonthWeek(week, this.monthAnchor(), this.weekWidthVp, x, y);
    const day: Date | null = monthOpenDayFromHit(hit);
    if (day === null) {
      return;
    }
    this.onOpenDay(day);
  }

  private dateFontColor(day: Date): number {
    if (!isMonthGridDay(day, this.monthAnchor())) {
      return AppColors.ON_SURFACE_MUTED;
    }
    if (sameCalendarDay(day, new Date())) {
      return AppColors.AZURE;
    }
    return 0xFF000000;
  }

  private weekBodyHeight(week: MonthWeekLayout): number {
    return MONTH_DATE_ROW_HEIGHT + monthBarAreaHeight(week.laneCount, weekHasOverflow(week));
  }

  @Builder
  weekdayHeader() {
    Row() {
      ForEach(WEEKDAY_LABELS, (label: string) => {
        Text(label)
          .fontSize(12)
          .fontColor(AppColors.ON_SURFACE_MUTED)
          .width('14.28%')
          .textAlign(TextAlign.Center)
      }, (label: string) => label)
    }
    .width('100%')
    .height(MONTH_WEEKDAY_ROW_HEIGHT)
    .border({ width: { bottom: 1 }, color: 0x1F000000 })
  }

  @Builder
  dateCell(day: Date, week: MonthWeekLayout) {
    Column() {
      Row() {
        Text(this.dateLabel(day))
          .fontSize(12)
          .fontWeight(sameCalendarDay(day, new Date()) ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.dateFontColor(day))
        if (this.cellOverflow(week, day) > 0) {
          Text(`+${this.cellOverflow(week, day)}`)
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.AZURE)
        }
      }
      .width('100%')
      .height(MONTH_DATE_ROW_HEIGHT)
      .padding({ left: 4, right: 4 })
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor(this.cellBackground(day))
    .border({
      width: { right: 1, bottom: 1 },
      color: 0x1F000000
    })
  }

  @Builder
  weekVisual(week: MonthWeekLayout) {
    Stack() {
      Row() {
        ForEach(week.days, (day: Date) => {
          this.dateCell(day, week)
        }, (day: Date) => `${day.getTime()}`)
      }
      .width('100%')
      .height('100%')

      ForEach(week.bars, (bar: MonthPlacedBar) => {
        Text(bar.title)
          .fontSize(10)
          .fontColor(taskBarLabelArgb(this.barColor(bar.taskId)))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 4, right: 2 })
          .height(MONTH_BAR_HEIGHT)
          .width(monthBarWidth(bar.startFrac, bar.endFrac, this.weekWidthVp))
          .backgroundColor(this.barColor(bar.taskId))
          .position({
            x: monthBarLeft(bar.startFrac, this.weekWidthVp),
            y: MONTH_DATE_ROW_HEIGHT + monthBarTop(bar.lane) + 2
          })
      }, (bar: MonthPlacedBar) => `${bar.taskId}-${bar.startFrac}-${bar.lane}`)
    }
    .width('100%')
    .height('100%')
    .border({
      width: { left: 1 },
      color: 0x1F000000
    })
  }

  @Builder
  weekHitLayer(week: MonthWeekLayout) {
    Stack() {
      this.weekVisual(week)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .onClick((event: ClickEvent) => {
          this.openFromHit(week, event.x, event.y);
        })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  weekRow(week: MonthWeekLayout) {
    Column() {
      this.weekHitLayer(week)
    }
    .width('100%')
    .height(this.weekTileHeight())
  }

  @Builder
  weekList() {
    Column() {
      ForEach(this.layouts(), (week: MonthWeekLayout) => {
        this.weekRow(week)
      }, (week: MonthWeekLayout) => `${week.weekMonday.getTime()}`)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      this.weekdayHeader()
      Column() {
        this.weekList()
      }
      .width('100%')
      .layoutWeight(1)
      .onAreaChange((_old: Area, area: Area) => {
        this.applyBody(lengthVp(area.width), lengthVp(area.height));
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BAR_BACKGROUND)
  }
}
