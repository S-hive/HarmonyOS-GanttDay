import { GanttGeometry } from '../../domain/gantt/GanttGeometry';
import { DaySegmenter } from '../../domain/gantt/DaySegmenter';
import { LaneLayout } from '../../domain/gantt/LaneLayout';
import { CREATE_EDGE_REPEAT_MS, CreateEdgePush } from '../../domain/gantt/CreateEdgePush';
import { computeDayFitMinutes, daySpansTouchingDay, kDayViewMaxSpanMinutes } from '../../domain/gantt/DayVisibleRange';
import { proposeCreate, proposeMove, proposeResizeEnd, proposeResizeStart } from '../../domain/gantt/DayGestureMath';
import { CreateStroke, END_POPUP } from '../../domain/gesture/CreateStroke';
import { TapClassifier, TapDecision, TapHit } from '../../domain/gesture/TapClassifier';
import { FactorySwatches } from '../../domain/gantt/FactorySwatches';
import { GanttSegment } from '../../domain/models/GanttSegment';
import { Task } from '../../domain/models/Task';
import { dateOnly } from '../../domain/time/Calendar';
import { WallClock } from '../../domain/time/WallClock';
import { util } from '@kit.ArkTS';
import { MemoryTaskRepository } from '../../data/MemoryTaskRepository';
import { TaskListener, TaskRepository } from '../../platform/TaskRepository';
import { DeleteConfirm } from '../common/DeleteConfirm';
import { persistOrToast } from '../common/SaveFailureToast';
import { SideDrawer } from '../common/SideDrawer';
import { TaskForm, taskAfterFormClose } from '../task/TaskForm';
import { AppColors } from '../theme/AppColors';
import { CreateTaskPopup } from './CreateTaskPopup';
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
  movementExceedsSlop
} from './DayHitTest';

const HOUR_LABEL_FONT_PX: number = 30;
const HOUR_LABEL_AXIS_GAP: number = 3;
const HOUR_LABEL_TOP_PAD: number = 4;
const HEADER_HEIGHT: number = HOUR_LABEL_TOP_PAD + HOUR_LABEL_FONT_PX + HOUR_LABEL_AXIS_GAP;
const LANE_HEIGHT: number = 28;
const BAR_HEIGHT: number = 20;
const BAR_GAP: number = 4;
const BAR_RADIUS: number = 4;

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

function addRoundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  radius: number
): void {
  let r: number = radius;
  if (r * 2 > w) {
    r = w / 2;
  }
  if (r * 2 > h) {
    r = h / 2;
  }
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.arcTo(x + w, y, x + w, y + r, r);
  ctx.lineTo(x + w, y + h - r);
  ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
  ctx.lineTo(x + r, y + h);
  ctx.arcTo(x, y + h, x, y + h - r, r);
  ctx.lineTo(x, y + r);
  ctx.arcTo(x, y, x + r, y, r);
  ctx.closePath();
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
  @State drawerOpen: boolean = false;
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
  private titles: Map<string, string> = new Map<string, string>();
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
  private fitStartMin: number = 8 * 60;
  private fitEndMin: number = 22 * 60;
  private createProbes: number[] = [];
  private edgePush: CreateEdgePush = new CreateEdgePush();
  private edgeRepeatId: number = -1;
  private lastRawX: number = 0;

  aboutToAppear(): void {
    this.viewDate = dateOnly(this.date);
    this.sink.apply = (list: Task[]): void => {
      this.cachedTasks = list;
      if (!this.createStroke.isDragging() && !this.createOpen) {
        this.recomputeFit([]);
      }
      this.redraw();
    };
    this.bindWatch();
  }

  onParentDate(): void {
    const incoming: number = WallClock.minutes(dateOnly(this.date));
    if (incoming !== this.boundDay0) {
      this.applyViewDate(dateOnly(this.date), false);
    }
  }

  aboutToDisappear(): void {
    this.cancelPendingTap();
    this.clearEdgeRepeat();
    this.unwatch();
    this.unwatch = (): void => {
    };
    this.boundDay0 = -1;
  }

  private day0Of(): number {
    return WallClock.minutes(dateOnly(this.viewDate));
  }

  private applyViewDate(next: Date, notifyParent: boolean): void {
    const prevDay0: number = this.boundDay0;
    this.viewDate = dateOnly(next);
    const day0: number = this.day0Of();
    if (day0 !== prevDay0) {
      this.bindWatch();
      this.didFitScroll = false;
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
    const cur: Date = this.viewDate;
    this.applyViewDate(new Date(cur.getFullYear(), cur.getMonth(), cur.getDate() + delta), true);
  }

  private goToday(): void {
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
    const spans = daySpansTouchingDay(this.cachedTasks, day0);
    const fit = computeDayFitMinutes(8, 22, day0, spans, probes);
    this.fitStartMin = fit.start;
    this.fitEndMin = fit.end;
  }

  private clearCreateAxis(): void {
    this.createProbes = [];
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
    const extra: Task | null = this.preview !== null ? this.preview : this.createDraft;
    if (extra === null) {
      return this.cachedTasks;
    }
    const out: Task[] = [];
    let found: boolean = false;
    for (let i = 0; i < this.cachedTasks.length; i++) {
      if (this.cachedTasks[i].id === extra.id) {
        out.push(extra);
        found = true;
      } else {
        out.push(this.cachedTasks[i]);
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
    this.axisScrollable = ScrollDirection.Horizontal;
  }

  private startCreateDrag(canvasX: number): void {
    this.createStroke.begin(canvasX);
    this.axisScrollable = ScrollDirection.None;
    this.tapConsumed = true;
    this.updateCreatePreview();
  }

  private updateCreatePreview(): void {
    const span = proposeCreate(this.gestureGeo(), this.createStroke.x0(), this.createStroke.x1());
    const id: string = this.createDraft !== null ? this.createDraft.id : util.generateRandomUUID();
    const createdAt: number = this.createDraft !== null ?
      this.createDraft.createdAt : WallClock.minutes(new Date());
    this.createDraft = new Task(id, '', span.start, span.end, FactorySwatches.DEFAULT_ID, createdAt);
    this.preview = null;
    this.createStart = span.start;
    this.createEnd = span.end;
    this.redraw();
  }

  private cancelPendingTap(): void {
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
    if (TapClassifier.onWaitTimeout(hit) === TapDecision.OpenForm && hit.taskId !== null) {
      this.openForm(hit.taskId);
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
      this.tapTimerId = setTimeout(() => {
        this.fireWaitTimeout();
      }, TapClassifier.DOUBLE_MS);
      return;
    }
    this.cancelPendingTap();
    if (decision === TapDecision.Delete && curr.taskId !== null) {
      this.tapConsumed = true;
      this.askDelete(curr.taskId);
      return;
    }
    if (decision === TapDecision.Create) {
      this.startCreateDrag(canvasX);
    }
  }

  private openCreatePopup(): void {
    const draft: Task | null = this.createDraft;
    if (draft === null) {
      return;
    }
    let ax: number = this.drawGeo().xOf(draft.plannedStart);
    let ay: number = HEADER_HEIGHT + BAR_GAP;
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
  }

  private cancelCreate(): void {
    this.createOpen = false;
    this.createDraft = null;
    this.clearCreateAxis();
    this.releasePanIfIdle();
    this.redraw();
  }

  private confirmCreate(title: string): void {
    const trimmed: string = title.trim();
    const draft: Task | null = this.createDraft;
    this.createOpen = false;
    this.createDraft = null;
    this.clearCreateAxis();
    this.releasePanIfIdle();
    if (draft === null || trimmed.length === 0) {
      this.redraw();
      return;
    }
    persistOrToast(this.repo.upsert(new Task(
      draft.id,
      trimmed,
      draft.plannedStart,
      draft.plannedEnd,
      draft.autoSwatchId,
      draft.createdAt
    )));
  }

  private openForm(taskId: string): void {
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

  private async askDelete(taskId: string): Promise<void> {
    const task: Task | null = this.findTask(taskId);
    if (task === null) {
      return;
    }
    const ok: boolean = await DeleteConfirm.show(task.title);
    if (!ok) {
      return;
    }
    if (this.formBase !== null && this.formBase.id === taskId) {
      this.drawerOpen = false;
      this.formBase = null;
    }
    await persistOrToast(this.repo.delete(taskId));
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
    const day0: number = this.day0Of();
    const segs: GanttSegment[] = [];
    this.titles = new Map<string, string>();
    const shown: Task[] = this.tasksForDraw();
    const fitEndAbs: number = day0 + this.fitEndMin;
    for (let i = 0; i < shown.length; i++) {
      const task: Task = shown[i];
      this.titles.set(task.id, task.title);
      let d: number = WallClock.dayStart(day0 + this.fitStartMin);
      while (d < fitEndAbs) {
        const clip: GanttSegment[] = DaySegmenter.segmentsForDay(task, d);
        for (let j = 0; j < clip.length; j++) {
          segs.push(clip[j]);
        }
        d += 1440;
      }
    }
    const lanes: Map<string, number> = LaneLayout.assign(segs);
    const byId: Map<string, Task> = new Map<string, Task>();
    for (let t = 0; t < shown.length; t++) {
      byId.set(shown[t].id, shown[t]);
    }
    const bars: HitBar[] = [];
    for (let k = 0; k < segs.length; k++) {
      const seg: GanttSegment = segs[k];
      const owner: Task | undefined = byId.get(seg.taskId);
      const trueStart: boolean = owner !== undefined && seg.start === owner.plannedStart;
      const trueEnd: boolean = owner !== undefined && seg.end === owner.plannedEnd;
      const lane: number | undefined = lanes.get(LaneLayout.keyOf(seg));
      const row: number = lane === undefined ? 0 : lane;
      const x: number = geo.xOf(seg.start);
      let w: number = geo.xOf(seg.end) - x;
      if (w < 2) {
        w = 2;
      }
      const y: number = HEADER_HEIGHT + row * LANE_HEIGHT + BAR_GAP;
      bars.push(new HitBar(seg.taskId, x, y, w, BAR_HEIGHT, trueStart, trueEnd));
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
    const startH: number = this.fitStartMin / 60;
    const endH: number = this.fitEndMin / 60;
    const hourPx: number = this.viewportWidthVp / (endH - startH);
    for (let h = startH; h <= endH; h++) {
      const t: number = day0 + h * 60;
      const x: number = geo.xOf(t);
      const labelH: number = ((h % 24) + 24) % 24;
      const emphasized: boolean = labelH % 6 === 0;
      ctx.strokeStyle = emphasized ? 'rgba(0, 0, 0, 0.14)' : 'rgba(0, 0, 0, 0.07)';
      ctx.beginPath();
      ctx.moveTo(x, HEADER_HEIGHT);
      ctx.lineTo(x, height);
      ctx.stroke();
      ctx.fillStyle = 'rgba(0, 0, 0, 0.55)';
      ctx.font = `${HOUR_LABEL_FONT_PX}px sans-serif`;
      ctx.textAlign = 'left';
      ctx.textBaseline = 'bottom';
      ctx.fillText(`${labelH}:00`, x + 4, HEADER_HEIGHT - HOUR_LABEL_AXIS_GAP);
    }

    if (hourPx > 40) {
      ctx.strokeStyle = 'rgba(0, 0, 0, 0.04)';
      for (let h = startH; h < endH; h++) {
        const base: number = geo.xOf(day0 + h * 60);
        for (let q = 1; q < 4; q++) {
          const x: number = base + hourPx * q / 4;
          ctx.beginPath();
          ctx.moveTo(x, HEADER_HEIGHT);
          ctx.lineTo(x, height);
          ctx.stroke();
        }
      }
    }
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
    for (let i = 0; i < this.hitBars.length; i++) {
      const b: HitBar = this.hitBars[i];
      ctx.fillStyle = argbToCss(AppColors.AZURE);
      ctx.beginPath();
      addRoundRect(ctx, b.x, b.y, b.width, b.height, BAR_RADIUS);
      ctx.fill();
      const title: string | undefined = this.titles.get(b.taskId);
      const label: string = title === undefined ? '' : title;
      ctx.save();
      ctx.beginPath();
      ctx.rect(b.x, b.y, b.width, b.height);
      ctx.clip();
      ctx.fillStyle = '#FFFFFF';
      ctx.font = '13px sans-serif';
      ctx.textAlign = 'left';
      ctx.textBaseline = 'middle';
      ctx.fillText(label, b.x + 6, b.y + b.height / 2);
      ctx.restore();
    }
  }

  private paintNowLine(ctx: CanvasRenderingContext2D, geo: GanttGeometry): void {
    const now: number = WallClock.minutes(new Date());
    const day0: number = this.day0Of();
    if (WallClock.dayStart(now) !== day0) {
      return;
    }
    const x: number = geo.xOf(now);
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
    const x: number = this.touchCanvasX(point);
    const y: number = point.y;

    if (event.type === TouchType.Down) {
      event.stopPropagation();
      const hit = hitTest(this.hitBars, x, y, DEFAULT_EDGE_SLOP);
      this.dragKind = hit.kind;
      this.dragTask = hit.taskId === null ? null : this.findTask(hit.taskId);
      this.grabX = x;
      this.grabY = y;
      this.startWindowX = point.windowX;
      this.startScrollX = this.scroller.currentOffset().xOffset;
      this.dragging = false;
      this.dragArmed = true;
      this.tapConsumed = false;
      this.preview = null;
      this.axisScrollable = ScrollDirection.None;
      if (this.tapTimerId !== -1) {
        clearTimeout(this.tapTimerId);
        this.tapTimerId = -1;
      }
      const curr: TapHit = this.toTapHit(hit.taskId, x, y);
      const nowMs: number = Date.now();
      const decision: TapDecision = TapClassifier.onDown(this.prevTap, this.prevTapMs, curr, nowMs);
      this.handleTapDecision(decision, curr, nowMs, x);
      return;
    }

    if (event.type === TouchType.Move && this.createStroke.isDragging()) {
      event.stopPropagation();
      this.lastRawX = point.x;
      this.createStroke.move(x);
      const geo = this.activeGeo();
      const probe = this.edgePush.applyPointer(
        point.x,
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

    if (event.type === TouchType.Move && this.dragArmed && !this.dragging && !this.tapConsumed) {
      const dx: number = x - this.grabX;
      const dy: number = y - this.grabY;
      const wdx: number = point.windowX - this.startWindowX;
      if (movementExceedsSlop(dx, dy, wdx, DAY_DRAG_START_SLOP)) {
        this.cancelPendingTap();
        this.dragging = true;
        this.dragArmed = false;
      }
    }

    if (event.type === TouchType.Move && this.dragging) {
      event.stopPropagation();
      if (this.dragKind === HIT_EMPTY) {
        const dx: number = point.windowX - this.startWindowX;
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

    if ((event.type === TouchType.Up || event.type === TouchType.Cancel) && this.createStroke.isDragging()) {
      event.stopPropagation();
      this.dragArmed = false;
      this.dragging = false;
      this.tapConsumed = false;
      if (event.type === TouchType.Up) {
        const endKind = this.createStroke.finish();
        if (endKind === END_POPUP) {
          this.openCreatePopup();
        } else {
          this.createDraft = null;
          this.clearCreateAxis();
          this.redraw();
          this.releasePanIfIdle();
        }
      } else {
        this.createStroke.abort();
        this.createDraft = null;
        this.clearCreateAxis();
        this.redraw();
        this.releasePanIfIdle();
      }
      return;
    }

    if ((event.type === TouchType.Up || event.type === TouchType.Cancel) &&
      (this.dragging || this.dragArmed)) {
      event.stopPropagation();
      const pending: Task | null = this.preview;
      const wasDragging: boolean = this.dragging;
      this.dragging = false;
      this.dragArmed = false;
      this.tapConsumed = false;
      this.preview = null;
      this.dragTask = null;
      this.dragKind = HIT_EMPTY;
      this.releasePanIfIdle();
      if (wasDragging && pending !== null && event.type === TouchType.Up) {
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

  @Builder
  dayTitleBar() {
    Row() {
      Text('GanttDay')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor('#232429')
        .flexShrink(0)
      Text('<')
        .fontSize(28)
        .fontColor('#232429')
        .flexShrink(0)
        .padding({ left: 24, right: 8 })
        .onClick(() => {
          this.goByDays(-1);
        })
      Text(this.dayTitle())
        .fontSize(16)
        .fontColor('#232429')
        .flexShrink(0)
        .margin({ left: 4, right: 4 })
      Text('>')
        .fontSize(28)
        .fontColor('#232429')
        .flexShrink(0)
        .padding({ left: 8, right: 8 })
        .onClick(() => {
          this.goByDays(1);
        })
      Text('今天')
        .fontSize(16)
        .fontColor(AppColors.AZURE)
        .flexShrink(0)
        .padding({ left: 12, right: 8 })
        .onClick(() => {
          this.goToday();
        })
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.White)
  }

  build() {
    Column() {
      this.dayTitleBar()
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
        }
        .scrollable(this.axisScrollable)
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
        .onAreaChange((_old: Area, area: Area) => {
          this.applyViewport(lengthVp(area.width), lengthVp(area.height));
        })
        if (this.createOpen) {
          CreateTaskPopup({
            anchorX: this.createAnchorX,
            anchorY: this.createAnchorY,
            anchorW: this.createAnchorW,
            anchorH: this.createAnchorH,
            start: this.createStart,
            end: this.createEnd,
            screenW: this.viewportWidthVp,
            screenH: this.viewportHeightVp,
            onConfirm: (title: string) => {
              this.confirmCreate(title);
            },
            onCancel: () => {
              this.cancelCreate();
            }
          })
        }
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
      .hitTestBehavior(HitTestMode.Block)
    }
    .width('100%')
    .height('100%')
  }
}
