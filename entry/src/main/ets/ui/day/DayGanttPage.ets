import { GanttGeometry, nowLineX } from '../../domain/gantt/GanttGeometry';
import { DaySegmenter } from '../../domain/gantt/DaySegmenter';
import { LaneLayout } from '../../domain/gantt/LaneLayout';
import { CREATE_EDGE_REPEAT_MS, CreateEdgePush } from '../../domain/gantt/CreateEdgePush';
import {
  LONG_PRESS_MS,
  actualEditBannerText,
  bindActualEditCloser,
  dayBarSpanEnd,
  dayBarSpanStart,
  dayBarUsesActual,
  plannedInnerStrip
} from '../../domain/gantt/ActualEdit';
import { computeDayFitMinutes, daySpansTouchingDay, kDayViewMaxSpanMinutes, todayNowProbes } from '../../domain/gantt/DayVisibleRange';
import { proposeCreate, proposeMove, proposeResizeEnd, proposeResizeStart, clampXToView } from '../../domain/gantt/DayGestureMath';
import { CreateStroke, END_POPUP } from '../../domain/gesture/CreateStroke';
import { TapClassifier, TapDecision, TapHit } from '../../domain/gesture/TapClassifier';
import { dayHourMark, layoutDateBadge, skipBodyHourTick } from '../../domain/gantt/DayHourMarks';
import { FactorySwatches } from '../../domain/gantt/FactorySwatches';
import { resolvedSwatchArgb, taskBarArgb, taskBarLabelArgb } from '../../domain/gantt/TaskBarTone';
import { GanttSegment } from '../../domain/models/GanttSegment';
import { Task } from '../../domain/models/Task';
import { dateOnly } from '../../domain/time/Calendar';
import { WallClock } from '../../domain/time/WallClock';
import { util } from '@kit.ArkTS';
import { MemoryTaskRepository } from '../../data/MemoryTaskRepository';
import { TaskListener, TaskRepository } from '../../platform/TaskRepository';
import { persistOrToast } from '../common/SaveFailureToast';
import { SideDrawer } from '../common/SideDrawer';
import { bindDeleteVeilCloser, DELETE_VEIL_BOTTOM, DELETE_VEIL_TOP } from '../common/DeleteVeilOverlay';
import { TaskForm, taskAfterFormClose } from '../task/TaskForm';
import { AppColors } from '../theme/AppColors';
import { CreateTaskPopup, formatBarCaption, formatBarTimeLabel } from './CreateTaskPopup';
import {
  DAY_DRAG_START_SLOP,
  DEFAULT_EDGE_SLOP,
  HIT_EMPTY,
  HIT_MOVE,
  HIT_RESIZE_END,
  HIT_RESIZE_START,
  HitBar,
  canvasXFromTouch,
  hitTest,
  laneIndexFromY,
  movementExceedsSlop,
  shouldCancelDoubleTapOnMove,
  snapshotTaskLanes
} from './DayHitTest';

const BAR_GAP: number = 2;
const BAR_HEIGHT: number = (28 * 0.88 - 2) * 0.96;
const BAR_LABEL_FONT_PX: number = 28 * 0.88 * 1.10 * 1.10;
const BAR_LABEL_PAD: number = 4;
const LANE_HEIGHT: number = BAR_HEIGHT + BAR_GAP * 2;
const DRAFT_LANE_INSET: number = BAR_GAP;
const DRAFT_BAR_HEIGHT: number = LANE_HEIGHT - DRAFT_LANE_INSET * 2;
const DRAFT_LABEL_PAD: number = 1.5;
const HOUR_LABEL_FONT_PX: number = 35;
const HOUR_LABEL_LEFT_PAD: number = 4;
const DATE_BADGE_PAD_PX: number = 5;
const DATE_BADGE_RADIUS: number = 2;
const HEADER_HEIGHT: number = HOUR_LABEL_FONT_PX + 8;
const NOW_LINE_MS: number = 30000;

class PageTaskSink implements TaskListener {
  apply: (tasks: Task[]) => void = (_tasks: Task[]): void => {
  };

  onTasks(tasks: Task[]): void {
    this.apply(tasks);
  }
}

function argbToCss(argb: number): string {
  const a: number = ((argb >>> 24) & 0xFF) / 255;
  const r: number = (argb >> 16) & 0xFF;
  const g: number = (argb >> 8) & 0xFF;
  const b: number = argb & 0xFF;
  return `rgba(${r}, ${g}, ${b}, ${a})`;
}

function lengthVp(value: Length): number {
  return parseFloat(`${value}`);
}

@Component
export struct DayGanttPage {
  repo: TaskRepository = new MemoryTaskRepository();
  @Prop @Watch('onParentDate') date: Date = new Date();
  @State viewDate: Date = dateOnly(new Date());
  onShift: (delta: number) => void = (_delta: number) => {
  };
  onGoToday: () => void = () => {
  };
  onActualEditModeChanged: (active: boolean) => void = (_active: boolean): void => {
  };
  @State canvasWidthVp: number = 1400;
  @State viewportWidthVp: number = 800;
  @State viewportHeightVp: number = 400;
  @State axisScrollable: ScrollDirection = ScrollDirection.Horizontal;
  @State createOpen: boolean = false;
  @State createAnchorX: number = 0;
  @State createAnchorY: number = 0;
  @State createAnchorW: number = 60;
  @State createAnchorH: number = BAR_HEIGHT;
  @State createStart: number = 0;
  @State createEnd: number = 0;
  @State actualEditTaskId: string = '';
  @State actualEditLane: number = 0;
  @State drawerOpen: boolean = false;
  @State deleteVeilTaskId: string = '';
  @State formTitle: string = '';
  @State formStart: number = 0;
  @State formEnd: number = 0;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private scroller: Scroller = new Scroller();
  private sink: PageTaskSink = new PageTaskSink();
  private unwatch: () => void = (): void => {
  };
  private boundDay0: number = -1;
  private cachedTasks: Task[] = [];
  private hitBars: HitBar[] = [];
  private canvasReady: boolean = false;
  private didFitScroll: boolean = false;
  private dragging: boolean = false;
  private dragArmed: boolean = false;
  private tapConsumed: boolean = false;
  private dragKind: string = HIT_EMPTY;
  private dragTask: Task | null = null;
  private grabX: number = 0;
  private grabY: number = 0;
  private startWindowX: number = 0;
  private startScrollX: number = 0;
  private preview: Task | null = null;
  private createDraft: Task | null = null;
  private formBase: Task | null = null;
  private prevTap: TapHit | null = null;
  private prevTapMs: number = 0;
  private pendingHit: TapHit | null = null;
  private tapTimerId: number = -1;
  private createStroke: CreateStroke = new CreateStroke();
  private createAnchorMin: number = 0;
  private touchSession: boolean = false;
  private fitStartMin: number = 8 * 60;
  private fitEndMin: number = 22 * 60;
  private createProbes: number[] = [];
  private edgePush: CreateEdgePush = new CreateEdgePush();
  private edgeRepeatId: number = -1;
  private lastRawX: number = 0;
  private createDlg: CustomDialogController | null = null;
  private createDlgSettled: boolean = false;
  private createLane: number = 0;
  private pinnedLanes: Map<string, number> | null = null;
  private longPressTimerId: number = -1;
  private longPressHitActual: boolean = false;
  private ignoreNextActualEditUp: boolean = false;
  private nowTimerId: number = -1;

  aboutToAppear(): void {
    this.viewDate = dateOnly(this.date);
    this.sink.apply = (list: Task[]): void => {
      this.cachedTasks = list;
      if (!this.createStroke.isDragging() && !this.createOpen && this.actualEditTaskId.length === 0) {
        this.recomputeFit([]);
      }
      this.redraw();
    };
    this.bindWatch();
    this.recomputeFit([]);
    this.startNowTimer();
    bindActualEditCloser(() => {
      this.exitActualEdit();
    });
  }

  onParentDate(): void {
    const incoming: number = WallClock.minutes(dateOnly(this.date));
    if (incoming !== this.boundDay0) {
      this.applyViewDate(dateOnly(this.date), false);
    }
  }

  aboutToDisappear(): void {
    this.createDlgSettled = true;
    this.closeCreateDlg();
    this.cancelPendingTap();
    this.cancelLongPress();
    this.clearNowTimer();
    this.exitActualEdit();
    this.dismissDeleteVeil();
    bindActualEditCloser(null);
    this.clearEdgeRepeat();
    this.unwatch();
    this.unwatch = (): void => {
    };
    this.boundDay0 = -1;
  }

  private day0Of(): number {
    return WallClock.minutes(dateOnly(this.viewDate));
  }

  private isCreateBlockingDayChange(): boolean {
    return this.createStroke.isDragging() || this.createOpen || this.actualEditTaskId.length > 0;
  }

  private applyViewDate(next: Date, notifyParent: boolean): void {
    if (this.isCreateBlockingDayChange()) {
      return;
    }
    const prevDay0: number = this.boundDay0;
    this.viewDate = dateOnly(next);
    const day0: number = this.day0Of();
    if (day0 !== prevDay0) {
      this.pinnedLanes = null;
      this.exitActualEdit();
      this.bindWatch();
      this.didFitScroll = false;
      this.recomputeFit([]);
      this.scrollToFit();
      this.redraw();
    }
    if (notifyParent) {
      const deltaDays: number = Math.round((day0 - prevDay0) / WallClock.MINUTES_PER_DAY);
      if (deltaDays !== 0) {
        this.onShift(deltaDays);
      }
    }
  }

  private goByDays(delta: number): void {
    if (this.isCreateBlockingDayChange()) {
      return;
    }
    const cur: Date = this.viewDate;
    this.applyViewDate(new Date(cur.getFullYear(), cur.getMonth(), cur.getDate() + delta), true);
  }

  private goToday(): void {
    if (this.isCreateBlockingDayChange()) {
      return;
    }
    this.applyViewDate(dateOnly(new Date()), true);
    this.onGoToday();
  }

  private bindWatch(): void {
    this.unwatch();
    const day0: number = this.day0Of();
    this.boundDay0 = day0;
    this.unwatch = this.repo.watchOverlapping(day0, day0 + kDayViewMaxSpanMinutes, this.sink);
  }

  private activeGeo(): GanttGeometry {
    const day0: number = this.day0Of();
    return new GanttGeometry(day0 + this.fitStartMin, day0 + this.fitEndMin, this.viewportWidthVp);
  }

  private drawGeo(): GanttGeometry {
    return this.activeGeo();
  }

  private gestureGeo(): GanttGeometry {
    return this.activeGeo();
  }

  private recomputeFit(probes: number[]): void {
    const day0: number = this.day0Of();
    const now: number = WallClock.minutes(new Date());
    const include: number[] = todayNowProbes(day0, now).concat(probes);
    const spans = daySpansTouchingDay(this.cachedTasks, day0);
    const fit = computeDayFitMinutes(8, 22, day0, spans, include);
    this.fitStartMin = fit.start;
    this.fitEndMin = fit.end;
  }

  private startNowTimer(): void {
    this.clearNowTimer();
    this.nowTimerId = setInterval((): void => {
      if (!this.createStroke.isDragging() && !this.createOpen && this.actualEditTaskId.length === 0) {
        this.recomputeFit([]);
      }
      this.redraw();
    }, NOW_LINE_MS);
  }

  private clearNowTimer(): void {
    if (this.nowTimerId !== -1) {
      clearInterval(this.nowTimerId);
      this.nowTimerId = -1;
    }
  }

  private clearCreateAxis(): void {
    this.createProbes = [];
    this.createLane = 0;
    this.edgePush.reset();
    this.clearEdgeRepeat();
    this.recomputeFit([]);
    this.releasePanIfIdle();
  }

  private clearEdgeRepeat(): void {
    if (this.edgeRepeatId !== -1) {
      clearInterval(this.edgeRepeatId);
      this.edgeRepeatId = -1;
    }
  }

  private applyProbe(probe: number | null): void {
    if (probe === null) {
      return;
    }
    const next: number[] = [];
    let minP: number = probe;
    let maxP: number = probe;
    for (let i = 0; i < this.createProbes.length; i++) {
      const p: number = this.createProbes[i];
      if (p < minP) {
        minP = p;
      }
      if (p > maxP) {
        maxP = p;
      }
      next.push(p);
    }
    next.push(probe);
    this.createProbes = [minP, maxP];
    this.recomputeFit(this.createProbes);
  }

  private syncEdgeRepeat(): void {
    const want: boolean = this.edgePush.shouldHoldRepeat(this.lastRawX, this.viewportWidthVp);
    if (!want) {
      this.clearEdgeRepeat();
      return;
    }
    if (this.edgeRepeatId !== -1) {
      return;
    }
    this.edgeRepeatId = setInterval(() => {
      if (!this.createStroke.isDragging()) {
        this.clearEdgeRepeat();
        return;
      }
      const geo = this.activeGeo();
      const hourPx: number = this.viewportWidthVp / ((geo.viewEnd - geo.viewStart) / 60);
      const probe = this.edgePush.holdTick(
        this.lastRawX,
        this.viewportWidthVp,
        hourPx,
        geo.viewStart,
        geo.viewEnd,
        this.day0Of()
      );
      this.applyProbe(probe);
      this.updateCreatePreview();
    }, CREATE_EDGE_REPEAT_MS);
  }

  private findTask(id: string): Task | null {
    for (let i = 0; i < this.cachedTasks.length; i++) {
      if (this.cachedTasks[i].id === id) {
        return this.cachedTasks[i];
      }
    }
    return null;
  }

  private tasksForDraw(): Task[] {
    let base: Task[] = this.cachedTasks;
    if (this.actualEditTaskId.length > 0) {
      base = [];
      const edit: Task | null = this.findTask(this.actualEditTaskId);
      if (edit !== null) {
        base.push(edit);
      }
    }
    const extra: Task | null = this.preview !== null ? this.preview : this.createDraft;
    if (extra === null) {
      return base;
    }
    const out: Task[] = [];
    let found: boolean = false;
    for (let i = 0; i < base.length; i++) {
      if (base[i].id === extra.id) {
        out.push(extra);
        found = true;
      } else {
        out.push(base[i]);
      }
    }
    if (!found) {
      out.push(extra);
    }
    return out;
  }

  private touchCanvasX(point: TouchObject): number {
    return canvasXFromTouch(point.x, this.scroller.currentOffset().xOffset, this.canvasWidthVp);
  }

  private releasePanIfIdle(): void {
    if (this.tapTimerId !== -1 || this.dragging || this.dragArmed ||
      this.createStroke.isDragging()) {
      return;
    }
    if (this.prevTap !== null && this.prevTap.taskId === null) {
      return;
    }
    this.axisScrollable = ScrollDirection.Horizontal;
  }

  private startCreateDrag(canvasX: number, canvasY: number): void {
    this.createLane = laneIndexFromY(canvasY, HEADER_HEIGHT, LANE_HEIGHT);
    this.pinnedLanes = snapshotTaskLanes(this.hitBars, HEADER_HEIGHT, LANE_HEIGHT);
    const geo: GanttGeometry = this.gestureGeo();
    this.createAnchorMin = geo.snap(geo.timeOf(clampXToView(geo, canvasX)));
    this.createStroke.begin(canvasX);
    this.axisScrollable = ScrollDirection.None;
    this.tapConsumed = true;
    this.updateCreatePreview();
  }

  private updateCreatePreview(): void {
    const geo: GanttGeometry = this.gestureGeo();
    const x0: number = clampXToView(geo, geo.xOf(this.createAnchorMin));
    const span = proposeCreate(geo, x0, this.createStroke.x1());
    const id: string = this.createDraft !== null ? this.createDraft.id : util.generateRandomUUID();
    this.createDraft = new Task(id, '', span.start, span.end, FactorySwatches.DEFAULT_ID, 0);
    this.preview = null;
    this.createStart = span.start;
    this.createEnd = span.end;
    this.redraw();
  }

  private cancelPendingTap(): void {
    this.cancelLongPress();
    if (this.tapTimerId !== -1) {
      clearTimeout(this.tapTimerId);
      this.tapTimerId = -1;
    }
    this.prevTap = null;
    this.prevTapMs = 0;
    this.pendingHit = null;
  }

  private fireWaitTimeout(): void {
    this.tapTimerId = -1;
    const hit: TapHit | null = this.pendingHit;
    this.prevTap = null;
    this.prevTapMs = 0;
    this.pendingHit = null;
    if (hit === null) {
      this.releasePanIfIdle();
      return;
    }
    const pointerDown: boolean = this.dragArmed || this.longPressTimerId !== -1;
    const longPressPending: boolean = this.longPressTimerId !== -1;
    if (TapClassifier.onWaitTimeout(hit) === TapDecision.OpenForm && hit.taskId !== null &&
      TapClassifier.shouldOpenDeleteVeilOnWaitTimeout(pointerDown, longPressPending, this.isActualEdit())) {
      this.openDeleteVeil(hit.taskId);
    }
    this.releasePanIfIdle();
  }

  private toTapHit(taskId: string | null, x: number, y: number): TapHit {
    const hit: TapHit = new TapHit();
    hit.x = x;
    hit.y = y;
    hit.taskId = taskId;
    return hit;
  }

  private handleTapDecision(decision: TapDecision, curr: TapHit, nowMs: number, canvasX: number): void {
    if (decision === TapDecision.Wait) {
      this.prevTap = curr;
      this.prevTapMs = nowMs;
      this.pendingHit = curr;
      return;
    }
    this.cancelPendingTap();
    if (decision === TapDecision.Create) {
      this.startCreateDrag(canvasX, curr.y);
    }
  }

  private openCreatePopup(): void {
    const draft: Task | null = this.createDraft;
    if (draft === null) {
      return;
    }
    let ax: number = this.drawGeo().xOf(draft.plannedStart);
    let ay: number = HEADER_HEIGHT + this.createLane * LANE_HEIGHT + BAR_GAP;
    let aw: number = this.drawGeo().xOf(draft.plannedEnd) - ax;
    let ah: number = BAR_HEIGHT;
    if (aw < 2) {
      aw = 2;
    }
    for (let i = 0; i < this.hitBars.length; i++) {
      if (this.hitBars[i].taskId === draft.id) {
        ax = this.hitBars[i].x;
        ay = this.hitBars[i].y;
        aw = this.hitBars[i].width;
        ah = this.hitBars[i].height;
        break;
      }
    }
    this.createStart = draft.plannedStart;
    this.createEnd = draft.plannedEnd;
    this.createAnchorX = ax - this.scroller.currentOffset().xOffset;
    this.createAnchorY = ay;
    this.createAnchorW = aw;
    this.createAnchorH = ah;
    this.createOpen = true;
    this.openCreateDialog();
  }

  private closeCreateDlg(): void {
    const dlg: CustomDialogController | null = this.createDlg;
    this.createDlg = null;
    if (dlg !== null) {
      dlg.close();
    }
  }

  private openCreateDialog(): void {
    this.createDlgSettled = false;
    this.closeCreateDlg();
    const dlg: CustomDialogController = new CustomDialogController({
      builder: CreateTaskPopup({
        start: this.createStart,
        end: this.createEnd,
        onConfirm: (title: string) => {
          this.confirmCreate(title);
        },
        onCancel: () => {
          this.cancelCreate();
        }
      }),
      cancel: () => {
        if (!this.createDlgSettled) {
          this.cancelCreate();
        }
      },
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true,
      backgroundColor: Color.Transparent
    });
    this.createDlg = dlg;
    dlg.open();
  }

  private cancelCreate(): void {
    if (this.createDlgSettled && this.createDlg === null && !this.createOpen) {
      return;
    }
    this.createDlgSettled = true;
    this.closeCreateDlg();
    this.createOpen = false;
    this.createDraft = null;
    this.pinnedLanes = null;
    this.clearCreateAxis();
    this.releasePanIfIdle();
    this.redraw();
  }

  private confirmCreate(title: string): void {
    const trimmed: string = title.trim();
    const draft: Task | null = this.createDraft;
    this.createDlgSettled = true;
    this.closeCreateDlg();
    this.createOpen = false;
    this.createDraft = null;
    if (draft === null || trimmed.length === 0) {
      this.pinnedLanes = null;
      this.clearCreateAxis();
      this.releasePanIfIdle();
      this.redraw();
      return;
    }
    const saved: Task = new Task(
      draft.id,
      trimmed,
      draft.plannedStart,
      draft.plannedEnd,
      draft.autoSwatchId,
      WallClock.minutes(new Date())
    );
    persistOrToast(this.repo.upsert(saved));
    const next: Task[] = [];
    let found: boolean = false;
    for (let i = 0; i < this.cachedTasks.length; i++) {
      if (this.cachedTasks[i].id === saved.id) {
        next.push(saved);
        found = true;
      } else {
        next.push(this.cachedTasks[i]);
      }
    }
    if (!found) {
      next.push(saved);
    }
    this.cachedTasks = next;
    this.pinnedLanes = null;
    this.clearCreateAxis();
    this.releasePanIfIdle();
    this.redraw();
  }

  private cancelLongPress(): void {
    if (this.longPressTimerId !== -1) {
      clearTimeout(this.longPressTimerId);
      this.longPressTimerId = -1;
    }
    this.longPressHitActual = false;
  }

  private isActualEdit(): boolean {
    return this.actualEditTaskId.length > 0;
  }

  private enterActualEdit(taskId: string, lane: number): void {
    this.dismissDeleteVeil();
    this.cancelPendingTap();
    this.cancelLongPress();
    this.dragArmed = false;
    this.dragging = false;
    this.tapConsumed = true;
    this.actualEditTaskId = taskId;
    this.actualEditLane = lane;
    this.ignoreNextActualEditUp = true;
    this.onActualEditModeChanged(true);
    this.redraw();
  }

  private exitActualEdit(): void {
    if (!this.isActualEdit()) {
      return;
    }
    this.cancelLongPress();
    this.createDraft = null;
    if (this.createStroke.isDragging()) {
      this.createStroke.abort();
    }
    this.actualEditTaskId = '';
    this.actualEditLane = 0;
    this.onActualEditModeChanged(false);
    this.releasePanIfIdle();
    this.redraw();
  }

  private replaceCached(task: Task): void {
    const next: Task[] = [];
    for (let i = 0; i < this.cachedTasks.length; i++) {
      if (this.cachedTasks[i].id === task.id) {
        next.push(task);
      } else {
        next.push(this.cachedTasks[i]);
      }
    }
    this.cachedTasks = next;
  }

  private commitActualFromCreate(): void {
    const draft: Task | null = this.createDraft;
    const id: string = this.actualEditTaskId;
    this.createDraft = null;
    if (draft === null || id.length === 0) {
      this.clearCreateAxis();
      this.releasePanIfIdle();
      this.redraw();
      return;
    }
    const base: Task | null = this.findTask(id);
    if (base !== null) {
      this.replaceCached(base.copyWith(undefined, undefined, undefined, draft.plannedStart, draft.plannedEnd, true));
    }
    persistOrToast(this.repo.complete(id, draft.plannedStart, draft.plannedEnd));
    this.exitActualEdit();
  }

  private uncompleteAndExit(): void {
    const id: string = this.actualEditTaskId;
    if (id.length === 0) {
      return;
    }
    const base: Task | null = this.findTask(id);
    if (base !== null) {
      this.replaceCached(base.copyWith(
        undefined, undefined, undefined, undefined, undefined, false,
        undefined, undefined, undefined, true
      ));
    }
    persistOrToast(this.repo.uncomplete(id));
    this.exitActualEdit();
  }

  private openForm(taskId: string): void {
    if (this.isActualEdit()) {
      return;
    }
    const task: Task | null = this.findTask(taskId);
    if (task === null) {
      return;
    }
    this.formBase = task;
    this.formTitle = task.title;
    this.formStart = task.plannedStart;
    this.formEnd = task.plannedEnd;
    this.drawerOpen = true;
  }

  onBackPress(): boolean {
    if (this.isActualEdit()) {
      this.exitActualEdit();
      return true;
    }
    if (this.deleteVeilTaskId.length > 0) {
      this.dismissDeleteVeil();
      return true;
    }
    if (!this.drawerOpen) {
      return false;
    }
    this.closeDrawer();
    return true;
  }

  private closeDrawer(): void {
    const base: Task | null = this.formBase;
    this.drawerOpen = false;
    this.formBase = null;
    if (base === null) {
      return;
    }
    persistOrToast(this.repo.upsert(taskAfterFormClose(base, this.formTitle, this.formStart, this.formEnd)));
  }

  private openDeleteVeil(taskId: string): void {
    if (this.isActualEdit()) {
      return;
    }
    bindDeleteVeilCloser(() => {
      this.dismissDeleteVeil();
    });
    this.deleteVeilTaskId = taskId;
  }

  private dismissDeleteVeil(): void {
    bindDeleteVeilCloser(null);
    this.deleteVeilTaskId = '';
  }

  private confirmDeleteVeil(): void {
    const id: string = this.deleteVeilTaskId;
    this.dismissDeleteVeil();
    if (id.length === 0) {
      return;
    }
    persistOrToast(this.repo.delete(id));
  }

  private deleteFromForm(): void {
    const base: Task | null = this.formBase;
    this.drawerOpen = false;
    this.formBase = null;
    if (base === null) {
      return;
    }
    persistOrToast(this.repo.delete(base.id));
  }

  private rebuildBars(geo: GanttGeometry): void {
    const raw: GanttSegment[] = [];
    const shown: Task[] = this.tasksForDraw();
    for (let i = 0; i < shown.length; i++) {
      const task: Task = shown[i];
      const clip: GanttSegment[] = DaySegmenter.clipToRange(
        task.id,
        dayBarSpanStart(task, this.isActualEdit()),
        dayBarSpanEnd(task, this.isActualEdit()),
        geo.viewStart,
        geo.viewEnd
      );
      for (let j = 0; j < clip.length; j++) {
        raw.push(clip[j]);
      }
    }
    const segs: GanttSegment[] = DaySegmenter.mergeAbutting(raw);
    const draftId: string = this.createDraft === null ? '' : this.createDraft.id;
    const lanes: Map<string, number> = LaneLayout.assignExclusive(LaneLayout.withoutTask(segs, draftId));
    const byId: Map<string, Task> = new Map<string, Task>();
    for (let t = 0; t < shown.length; t++) {
      byId.set(shown[t].id, shown[t]);
    }
    const bars: HitBar[] = [];
    for (let k = 0; k < segs.length; k++) {
      const seg: GanttSegment = segs[k];
      const owner: Task | undefined = byId.get(seg.taskId);
      const spanStart: number = owner === undefined ?
        seg.start : dayBarSpanStart(owner, this.isActualEdit());
      const spanEnd: number = owner === undefined ? seg.end : dayBarSpanEnd(owner, this.isActualEdit());
      const trueStart: boolean = owner !== undefined && seg.start === spanStart;
      const trueEnd: boolean = owner !== undefined && seg.end === spanEnd;
      const usesActual: boolean = owner !== undefined && dayBarUsesActual(owner, this.isActualEdit());
      const lane: number | undefined = lanes.get(LaneLayout.keyOf(seg));
      const isDraft: boolean = draftId.length > 0 && seg.taskId === draftId;
      const pinned: number | undefined = this.pinnedLanes === null ?
        undefined : this.pinnedLanes.get(seg.taskId);
      const row: number = isDraft ? LaneLayout.nextFreeLane(lanes, this.createLane) :
        (this.isActualEdit() && seg.taskId === this.actualEditTaskId ? this.actualEditLane :
          (pinned !== undefined ? pinned : (lane === undefined ? 0 : lane)));
      const x: number = geo.xOf(seg.start);
      let w: number = geo.xOf(seg.end) - x;
      if (w < 2) {
        w = 2;
      }
      const y: number = isDraft ? HEADER_HEIGHT + row * LANE_HEIGHT + DRAFT_LANE_INSET :
        HEADER_HEIGHT + row * LANE_HEIGHT + BAR_GAP;
      const h: number = isDraft ? DRAFT_BAR_HEIGHT : BAR_HEIGHT;
      bars.push(new HitBar(seg.taskId, x, y, w, h, trueStart, trueEnd, usesActual));
    }
    this.hitBars = bars;
  }

  private scrollToFit(): void {
    if (this.didFitScroll || this.canvasWidthVp <= 0) {
      return;
    }
    this.didFitScroll = true;
    this.scroller.scrollTo({
      xOffset: 0,
      yOffset: 0,
      animation: false
    });
  }

  private applyViewport(width: number, height: number): void {
    if (width <= 0 || height <= 0) {
      return;
    }
    const sizeChanged: boolean = width !== this.viewportWidthVp || height !== this.viewportHeightVp;
    this.viewportWidthVp = width;
    this.viewportHeightVp = height;
    this.canvasWidthVp = width;
    if (sizeChanged) {
      this.didFitScroll = false;
    }
    this.scrollToFit();
    this.redraw();
  }

  private redraw(): void {
    if (!this.canvasReady) {
      return;
    }
    const ctx: CanvasRenderingContext2D = this.ctx;
    const cw: number = ctx.width;
    const ch: number = ctx.height;
    if (cw <= 0 || ch <= 0 || this.canvasWidthVp <= 0 || this.viewportHeightVp <= 0) {
      return;
    }
    const geo: GanttGeometry = this.drawGeo();
    this.rebuildBars(geo);
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, cw, ch);
    const sx: number = cw / this.canvasWidthVp;
    const sy: number = ch / this.viewportHeightVp;
    ctx.setTransform(sx, 0, 0, sy, 0, 0);
    this.paintGrid(ctx, geo);
    this.paintBars(ctx);
    this.paintNowLine(ctx, geo);
  }

  private paintGrid(ctx: CanvasRenderingContext2D, geo: GanttGeometry): void {
    const width: number = this.canvasWidthVp;
    const height: number = this.viewportHeightVp;
    const rowCount: number = Math.max(LaneLayout.laneCount(this.laneMapFromBars()),
      Math.ceil(Math.max(0, height - HEADER_HEIGHT) / LANE_HEIGHT));
    ctx.strokeStyle = 'rgba(0, 0, 0, 0.08)';
    ctx.lineWidth = 1;
    for (let r = 0; r <= rowCount; r++) {
      const y: number = HEADER_HEIGHT + r * LANE_HEIGHT;
      if (y > height) {
        break;
      }
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
    }

    const day0: number = this.day0Of();
    const startMin: number = this.fitStartMin;
    const endMin: number = this.fitEndMin;
    const hourPx: number = this.viewportWidthVp / ((endMin - startMin) / 60);
    for (let m = startMin; m <= endMin; m += 60) {
      const t: number = day0 + m;
      const x: number = geo.xOf(t);
      const mark = dayHourMark(day0, m);
      if (!mark.isDayBoundary && !skipBodyHourTick(m)) {
        ctx.strokeStyle = mark.emphasized ? 'rgba(0, 0, 0, 0.14)' : 'rgba(0, 0, 0, 0.07)';
        ctx.beginPath();
        ctx.moveTo(x, HEADER_HEIGHT);
        ctx.lineTo(x, height);
        ctx.stroke();
      }
      if (mark.isDayBoundary) {
        this.paintDateBadge(ctx, x, mark.label);
      } else {
        this.paintHourLabel(ctx, x, mark.label, mark.emphasized);
      }
    }

    if (hourPx > 40) {
      ctx.strokeStyle = 'rgba(0, 0, 0, 0.04)';
      ctx.lineWidth = 1;
      for (let m = startMin; m < endMin; m += 60) {
        const base: number = geo.xOf(day0 + m);
        for (let q = 1; q < 4; q++) {
          const tickMin: number = m + 15 * q;
          if (skipBodyHourTick(tickMin)) {
            continue;
          }
          const x: number = base + hourPx * q / 4;
          ctx.beginPath();
          ctx.moveTo(x, HEADER_HEIGHT);
          ctx.lineTo(x, height);
          ctx.stroke();
        }
      }
    }
  }

  private headerFontPx(ctx: CanvasRenderingContext2D): number {
    return HOUR_LABEL_FONT_PX * ctx.height / this.viewportHeightVp;
  }

  private paintHourLabel(ctx: CanvasRenderingContext2D, xVp: number, label: string, emphasized: boolean): void {
    const sx: number = ctx.width / this.canvasWidthVp;
    const sy: number = ctx.height / this.viewportHeightVp;
    ctx.save();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    const fontPx: number = this.headerFontPx(ctx);
    ctx.font = emphasized ? `bold ${fontPx}px sans-serif` : `${fontPx}px sans-serif`;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = 'rgba(0, 0, 0, 0.55)';
    ctx.fillText(label, (xVp + HOUR_LABEL_LEFT_PAD) * sx, HEADER_HEIGHT * sy / 2);
    ctx.restore();
  }

  private strokeRoundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number): void {
    let radius: number = r;
    if (radius > w / 2) {
      radius = w / 2;
    }
    if (radius > h / 2) {
      radius = h / 2;
    }
    ctx.beginPath();
    ctx.moveTo(x + radius, y);
    ctx.lineTo(x + w - radius, y);
    ctx.arcTo(x + w, y, x + w, y + radius, radius);
    ctx.lineTo(x + w, y + h - radius);
    ctx.arcTo(x + w, y + h, x + w - radius, y + h, radius);
    ctx.lineTo(x + radius, y + h);
    ctx.arcTo(x, y + h, x, y + h - radius, radius);
    ctx.lineTo(x, y + radius);
    ctx.arcTo(x, y, x + radius, y, radius);
    ctx.closePath();
    ctx.stroke();
  }

  private paintDateBadge(ctx: CanvasRenderingContext2D, xVp: number, label: string): void {
    const sx: number = ctx.width / this.canvasWidthVp;
    const sy: number = ctx.height / this.viewportHeightVp;
    ctx.save();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    const fontPx: number = this.headerFontPx(ctx);
    ctx.font = `bold ${fontPx}px sans-serif`;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'alphabetic';
    const metrics = ctx.measureText(label);
    const inkLeft: number = metrics.actualBoundingBoxLeft;
    const inkRight: number = metrics.actualBoundingBoxRight;
    const inkAscent: number = metrics.actualBoundingBoxAscent;
    const inkDescent: number = metrics.actualBoundingBoxDescent;
    let inkW: number = inkLeft + inkRight;
    let inkH: number = inkAscent + inkDescent;
    let ascent: number = inkAscent;
    let left: number = inkLeft;
    if (inkW <= 1) {
      inkW = metrics.width;
      left = 0;
    }
    if (inkH <= 1) {
      inkH = fontPx * 0.72;
      ascent = inkH * 0.8;
    }
    const pad: number = DATE_BADGE_PAD_PX;
    const originX: number = (xVp + HOUR_LABEL_LEFT_PAD) * sx;
    const box = layoutDateBadge(
      originX - left,
      inkW,
      inkH,
      HEADER_HEIGHT * sy,
      pad
    );
    const x0: number = Math.round(box.x);
    const y0: number = Math.round(box.y);
    const bw: number = Math.max(1, Math.round(box.w));
    const bh: number = Math.max(1, Math.round(box.h));
    const color: string = argbToCss(AppColors.DAY_BOUNDARY);
    ctx.strokeStyle = color;
    ctx.fillStyle = color;
    ctx.lineWidth = 1;
    this.strokeRoundRect(ctx, x0 + 0.5, y0 + 0.5, bw - 1, bh - 1, DATE_BADGE_RADIUS);
    ctx.fillText(label, x0 + pad + left, y0 + pad + ascent);
    ctx.restore();
  }

  private laneMapFromBars(): Map<string, number> {
    const lanes: Map<string, number> = new Map<string, number>();
    for (let i = 0; i < this.hitBars.length; i++) {
      const b: HitBar = this.hitBars[i];
      const lane: number = Math.round((b.y - HEADER_HEIGHT - BAR_GAP) / LANE_HEIGHT);
      lanes.set(`${b.taskId}:${i}`, lane);
    }
    return lanes;
  }

  private paintBars(ctx: CanvasRenderingContext2D): void {
    const draftId: string = this.createDraft === null ? '' : this.createDraft.id;
    const now: number = WallClock.minutes(new Date());
    const labeled: Map<string, boolean> = new Map<string, boolean>();
    for (let i = 0; i < this.hitBars.length; i++) {
      const b: HitBar = this.hitBars[i];
      const isDraft: boolean = draftId.length > 0 && b.taskId === draftId;
      let fill: number = AppColors.AZURE;
      if (isDraft) {
        ctx.fillStyle = argbToCss(AppColors.CREATE_PREVIEW);
        ctx.strokeStyle = argbToCss(AppColors.CREATE_PREVIEW_STROKE);
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.rect(b.x, b.y, b.width, b.height);
        ctx.fill();
        ctx.stroke();
      } else {
        const owner: Task | null = this.findTask(b.taskId);
        if (owner !== null) {
          fill = taskBarArgb(
            this.isActualEdit() ? false : owner.isDone,
            owner.plannedStart,
            owner.plannedEnd,
            now,
            resolvedSwatchArgb(owner)
          );
        }
        ctx.fillStyle = argbToCss(fill);
        ctx.beginPath();
        ctx.rect(b.x, b.y, b.width, b.height);
        ctx.fill();
        if (owner !== null && dayBarUsesActual(owner, this.isActualEdit())) {
          const geo: GanttGeometry = this.drawGeo();
          const px: number = geo.xOf(owner.plannedStart);
          let pw: number = geo.xOf(owner.plannedEnd) - px;
          if (pw < 2) {
            pw = 2;
          }
          const strip = plannedInnerStrip(b.x, b.y, b.width, b.height, px, pw);
          ctx.fillStyle = argbToCss(AppColors.PLANNED_GRAY);
          ctx.fillRect(strip.x, strip.y, strip.width, strip.height);
        }
      }
      if (labeled.has(b.taskId)) {
        continue;
      }
      labeled.set(b.taskId, true);
      let label: string = '';
      if (isDraft && this.createDraft !== null) {
        label = formatBarTimeLabel(this.createDraft.plannedStart, this.createDraft.plannedEnd);
      } else {
        const task: Task | null = this.findTask(b.taskId);
        if (task !== null) {
          if (b.isActual && task.actualStart !== null && task.actualEnd !== null) {
            label = formatBarCaption(task.title, task.actualStart, task.actualEnd);
          } else {
            label = formatBarCaption(task.title, task.plannedStart, task.plannedEnd);
          }
        }
      }
      if (label.length === 0) {
        continue;
      }
      const pad: number = isDraft ? DRAFT_LABEL_PAD : BAR_LABEL_PAD;
      const tx: number = b.x + pad;
      const ty: number = b.y + b.height / 2;
      ctx.font = `${BAR_LABEL_FONT_PX}px sans-serif`;
      ctx.textAlign = 'left';
      ctx.textBaseline = 'middle';
      const textW: number = ctx.measureText(label).width;
      const overflows: boolean = textW > b.width - pad * 2;
      const onBar: string = isDraft ? argbToCss(0xDE000000) : argbToCss(taskBarLabelArgb(fill));
      if (overflows) {
        ctx.fillStyle = argbToCss(0xDE000000);
        ctx.fillText(label, tx, ty);
      }
      ctx.save();
      ctx.beginPath();
      ctx.rect(b.x, b.y, b.width, b.height);
      ctx.clip();
      ctx.fillStyle = onBar;
      ctx.fillText(label, tx, ty);
      ctx.restore();
    }
  }

  private paintNowLine(ctx: CanvasRenderingContext2D, geo: GanttGeometry): void {
    const now: number = WallClock.minutes(new Date());
    const x: number | null = nowLineX(geo, now);
    if (x === null) {
      return;
    }
    ctx.strokeStyle = '#FF5252';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(x, HEADER_HEIGHT - 4);
    ctx.lineTo(x, this.viewportHeightVp);
    ctx.stroke();
  }

  private onCanvasTouch(event: TouchEvent): void {
    const point: TouchObject | undefined = event.type === TouchType.Up || event.type === TouchType.Cancel ?
      event.changedTouches[0] : event.touches[0];
    if (point === undefined) {
      return;
    }
    if (event.type === TouchType.Down) {
      this.touchSession = true;
    }
    this.onCanvasPointer(
      event.type,
      this.touchCanvasX(point),
      point.y,
      point.windowX,
      point.x,
      (): void => {
        event.stopPropagation();
      }
    );
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.touchSession = false;
    }
  }

  private onCanvasMouse(event: MouseEvent): void {
    let type: number = -1;
    if (event.action === MouseAction.Press) {
      if (this.touchSession || this.dragArmed || this.createStroke.isDragging()) {
        return;
      }
      type = TouchType.Down;
    } else if (event.action === MouseAction.Move) {
      if (!this.createStroke.isDragging() && !this.dragging && !this.dragArmed) {
        return;
      }
      type = TouchType.Move;
    } else if (event.action === MouseAction.Release) {
      if (!this.createStroke.isDragging() && !this.dragging && !this.dragArmed) {
        return;
      }
      type = TouchType.Up;
    } else {
      return;
    }
    const x: number = canvasXFromTouch(event.x, this.scroller.currentOffset().xOffset, this.canvasWidthVp);
    this.onCanvasPointer(type, x, event.y, event.windowX, event.x, (): void => {
      event.stopPropagation();
    });
    if (type === TouchType.Up) {
      this.touchSession = false;
    }
  }

  private onCanvasPointer(
    type: number,
    x: number,
    y: number,
    windowX: number,
    rawX: number,
    stop: () => void
  ): void {
    if (this.deleteVeilTaskId.length > 0) {
      return;
    }
    if (type === TouchType.Down) {
      stop();
      const hit = hitTest(this.hitBars, x, y, DEFAULT_EDGE_SLOP);
      this.dragKind = hit.kind;
      this.dragTask = hit.taskId === null ? null : this.findTask(hit.taskId);
      this.grabX = x;
      this.grabY = y;
      this.startWindowX = windowX;
      this.startScrollX = this.scroller.currentOffset().xOffset;
      this.dragging = false;
      this.dragArmed = !this.isActualEdit();
      this.tapConsumed = false;
      this.preview = null;
      this.cancelLongPress();
      if (hit.kind !== HIT_EMPTY && !this.isActualEdit()) {
        this.pinnedLanes = snapshotTaskLanes(this.hitBars, HEADER_HEIGHT, LANE_HEIGHT);
      }
      this.axisScrollable = ScrollDirection.None;
      if (this.tapTimerId !== -1) {
        clearTimeout(this.tapTimerId);
        this.tapTimerId = -1;
      }
      if (this.isActualEdit()) {
        this.longPressHitActual = hit.isActual;
        this.longPressTimerId = setTimeout(() => {
          this.longPressTimerId = -1;
          if (this.longPressHitActual) {
            const edit: Task | null = this.findTask(this.actualEditTaskId);
            if (edit !== null && edit.isDone) {
              this.uncompleteAndExit();
              return;
            }
          }
          this.startCreateDrag(x, y);
        }, LONG_PRESS_MS);
        return;
      }
      const pressId: string | null = hit.taskId;
      if (pressId !== null) {
        this.longPressTimerId = setTimeout(() => {
          this.longPressTimerId = -1;
          const lane: number = laneIndexFromY(y, HEADER_HEIGHT, LANE_HEIGHT);
          this.enterActualEdit(pressId, lane);
        }, LONG_PRESS_MS);
      } else if (TapClassifier.shouldStartCreateOnLongPress(pressId)) {
        this.longPressTimerId = setTimeout(() => {
          this.longPressTimerId = -1;
          this.cancelPendingTap();
          this.startCreateDrag(this.grabX, this.grabY);
        }, LONG_PRESS_MS);
      }
      const curr: TapHit = this.toTapHit(hit.taskId, x, y);
      const nowMs: number = Date.now();
      const decision: TapDecision = TapClassifier.onDown(this.prevTap, this.prevTapMs, curr, nowMs);
      this.handleTapDecision(decision, curr, nowMs, x);
      if (this.tapConsumed) {
        this.cancelLongPress();
      }
      return;
    }

    if (type === TouchType.Move && this.longPressTimerId !== -1) {
      const dx0: number = x - this.grabX;
      const dy0: number = y - this.grabY;
      const wdx0: number = windowX - this.startWindowX;
      if (movementExceedsSlop(dx0, dy0, wdx0, DAY_DRAG_START_SLOP)) {
        this.cancelLongPress();
        if (this.isActualEdit() && !this.createStroke.isDragging()) {
          this.startCreateDrag(this.grabX, this.grabY);
          this.createStroke.move(x);
          this.lastRawX = rawX;
          this.updateCreatePreview();
          return;
        }
      }
    }

    if (type === TouchType.Move && this.createStroke.isDragging()) {
      stop();
      this.lastRawX = rawX;
      this.createStroke.move(x);
      const geo = this.activeGeo();
      const probe = this.edgePush.applyPointer(
        rawX,
        this.viewportWidthVp,
        geo.viewStart,
        geo.viewEnd,
        this.day0Of()
      );
      this.applyProbe(probe);
      this.syncEdgeRepeat();
      this.updateCreatePreview();
      return;
    }

    if (type === TouchType.Move && this.dragArmed && !this.dragging && !this.tapConsumed) {
      const dx: number = x - this.grabX;
      const dy: number = y - this.grabY;
      const wdx: number = windowX - this.startWindowX;
      if (movementExceedsSlop(dx, dy, wdx, DAY_DRAG_START_SLOP)) {
        this.cancelLongPress();
        const pendingId: string | null = this.pendingHit === null ? null : this.pendingHit.taskId;
        if (shouldCancelDoubleTapOnMove(pendingId)) {
          this.cancelPendingTap();
          this.dragging = true;
          this.dragArmed = false;
        }
      }
    }

    if (type === TouchType.Move && this.dragging) {
      stop();
      if (this.dragKind === HIT_EMPTY) {
        const dx: number = windowX - this.startWindowX;
        let next: number = this.startScrollX - dx;
        if (next < 0) {
          next = 0;
        }
        const max: number = this.canvasWidthVp - this.viewportWidthVp;
        if (next > max) {
          next = max;
        }
        this.scroller.scrollTo({ xOffset: next, yOffset: 0, animation: false });
        return;
      }
      if (this.dragTask === null) {
        return;
      }
      const geo: GanttGeometry = this.gestureGeo();
      if (this.dragKind === HIT_MOVE) {
        this.preview = proposeMove(this.dragTask, geo, x - this.grabX);
      } else if (this.dragKind === HIT_RESIZE_START) {
        this.preview = proposeResizeStart(this.dragTask, geo, x);
      } else if (this.dragKind === HIT_RESIZE_END) {
        this.preview = proposeResizeEnd(this.dragTask, geo, x);
      }
      this.redraw();
      return;
    }

    if ((type === TouchType.Up || type === TouchType.Cancel) &&
      this.isActualEdit() && !this.createStroke.isDragging()) {
      stop();
      this.cancelLongPress();
      this.dragArmed = false;
      this.dragging = false;
      if (this.ignoreNextActualEditUp) {
        this.ignoreNextActualEditUp = false;
        this.releasePanIfIdle();
        return;
      }
      if (type === TouchType.Up) {
        this.exitActualEdit();
      }
      this.releasePanIfIdle();
      return;
    }

    if ((type === TouchType.Up || type === TouchType.Cancel) && this.createStroke.isDragging()) {
      stop();
      this.dragArmed = false;
      this.dragging = false;
      this.tapConsumed = false;
      if (type === TouchType.Up) {
        const endKind = this.createStroke.finish();
        if (endKind === END_POPUP) {
          if (this.isActualEdit()) {
            this.commitActualFromCreate();
          } else {
            this.openCreatePopup();
          }
        } else {
          this.createDraft = null;
          this.pinnedLanes = null;
          this.clearCreateAxis();
          this.redraw();
          this.releasePanIfIdle();
        }
      } else {
        this.createStroke.abort();
        this.createDraft = null;
        this.pinnedLanes = null;
        this.clearCreateAxis();
        this.redraw();
        this.releasePanIfIdle();
      }
      return;
    }

    if ((type === TouchType.Up || type === TouchType.Cancel) &&
      (this.dragging || this.dragArmed)) {
      stop();
      this.cancelLongPress();
      const pending: Task | null = this.preview;
      const wasDragging: boolean = this.dragging;
      this.dragging = false;
      this.dragArmed = false;
      this.tapConsumed = false;
      this.preview = null;
      this.pinnedLanes = null;
      this.dragTask = null;
      this.dragKind = HIT_EMPTY;
      const releaseTaskId: string | null = this.pendingHit === null ? null : this.pendingHit.taskId;
      if (!wasDragging && type === TouchType.Up &&
        TapClassifier.shouldOpenDeleteVeilOnRelease(releaseTaskId, wasDragging, this.isActualEdit(), false) &&
        releaseTaskId !== null) {
        this.cancelPendingTap();
        this.openDeleteVeil(releaseTaskId);
      } else if (!wasDragging && type === TouchType.Up && this.pendingHit !== null &&
        this.pendingHit.taskId === null) {
        this.prevTapMs = Date.now();
        if (this.tapTimerId !== -1) {
          clearTimeout(this.tapTimerId);
        }
        this.tapTimerId = setTimeout(() => {
          this.fireWaitTimeout();
        }, TapClassifier.DOUBLE_MS);
      }
      this.releasePanIfIdle();
      if (wasDragging && pending !== null && type === TouchType.Up) {
        persistOrToast(this.repo.upsert(pending));
      } else if (wasDragging) {
        this.redraw();
      }
    }
  }

  private dayTitle(): string {
    const y: number = this.viewDate.getFullYear();
    const m: number = this.viewDate.getMonth() + 1;
    const d: number = this.viewDate.getDate();
    const ms: string = m < 10 ? `0${m}` : `${m}`;
    const ds: string = d < 10 ? `0${d}` : `${d}`;
    return `${y}-${ms}-${ds}`;
  }

  private actualEditTitle(): string {
    const task: Task | null = this.findTask(this.actualEditTaskId);
    return task === null ? '' : task.title;
  }

  private actualEditDone(): boolean {
    const task: Task | null = this.findTask(this.actualEditTaskId);
    return task !== null && task.isDone;
  }

  @Builder
  actualEditBanner() {
    Row() {
      Text(actualEditBannerText(this.actualEditTitle(), this.actualEditDone()))
        .fontSize(14)
        .fontColor('#232429')
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text('退出')
        .fontSize(16)
        .fontColor(AppColors.AZURE)
        .padding({ left: 12 })
        .onClick(() => {
          this.exitActualEdit();
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#E8EEF6')
  }

  @Builder
  dayTitleBar() {
    Row() {
      Text('GanttDay')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#232429')
        .flexShrink(0)
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(22)
        .fontColor(['#232429'])
        .flexShrink(0)
        .padding({ left: 24, right: 8 })
        .onClick(() => {
          if (this.isCreateBlockingDayChange()) {
            return;
          }
          this.goByDays(-1);
        })
      Text(this.dayTitle())
        .fontSize(14)
        .fontColor('#232429')
        .flexShrink(0)
        .margin({ left: 4, right: 4 })
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(22)
        .fontColor(['#232429'])
        .flexShrink(0)
        .padding({ left: 8, right: 8 })
        .onClick(() => {
          if (this.isCreateBlockingDayChange()) {
            return;
          }
          this.goByDays(1);
        })
      Text('今天')
        .fontSize(14)
        .fontColor(AppColors.AZURE)
        .flexShrink(0)
        .padding({ left: 12, right: 8 })
        .onClick(() => {
          if (this.isCreateBlockingDayChange()) {
            return;
          }
          this.goToday();
        })
    }
    .width('100%')
    .height(AppColors.CHROME_BAR_HEIGHT)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.White)
  }

  build() {
    Stack() {
      Column() {
        if (this.isActualEdit()) {
          this.actualEditBanner()
        } else {
          this.dayTitleBar()
        }
        Stack() {
          Scroll(this.scroller) {
            Canvas(this.ctx)
              .width(this.canvasWidthVp)
              .height(this.viewportHeightVp)
              .onReady(() => {
                this.canvasReady = true;
                this.redraw();
              })
              .onTouch((event: TouchEvent) => {
                this.onCanvasTouch(event);
              })
              .onMouse((event: MouseEvent) => {
                this.onCanvasMouse(event);
              })
          }
          .scrollable(this.deleteVeilTaskId.length > 0 ? ScrollDirection.None : this.axisScrollable)
          .scrollBar(BarState.Off)
          .width('100%')
          .height('100%')
          .hitTestBehavior(this.deleteVeilTaskId.length > 0 ? HitTestMode.None : HitTestMode.Default)
          .onAreaChange((_old: Area, area: Area) => {
            this.applyViewport(lengthVp(area.width), lengthVp(area.height));
          })
          if (this.drawerOpen) {
            SideDrawer({
              screenWidth: this.viewportWidthVp,
              onClose: () => {
                this.closeDrawer();
              }
            }) {
              TaskForm({
                title: $formTitle,
                plannedStart: $formStart,
                plannedEnd: $formEnd,
                onDelete: () => {
                  this.deleteFromForm();
                }
              })
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
        .hitTestBehavior(this.deleteVeilTaskId.length > 0 ? HitTestMode.None : HitTestMode.Default)
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(this.deleteVeilTaskId.length > 0 ? HitTestMode.None : HitTestMode.Default)

      if (this.deleteVeilTaskId.length > 0) {
        Column() {
          Column()
            .width('100%')
            .height('50%')
            .backgroundColor(DELETE_VEIL_TOP)
            .onClick(() => {
              this.confirmDeleteVeil();
            })
            .priorityGesture(
              TapGesture()
                .onAction(() => {
                  this.confirmDeleteVeil();
                })
            )
          Column()
            .width('100%')
            .height('50%')
            .backgroundColor(DELETE_VEIL_BOTTOM)
            .onClick(() => {
              this.dismissDeleteVeil();
            })
            .priorityGesture(
              TapGesture()
                .onAction(() => {
                  this.dismissDeleteVeil();
                })
            )
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
