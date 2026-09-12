import { MemoryTaskRepository } from '../../data/MemoryTaskRepository';
import { Task } from '../../domain/models/Task';
import { dateOnly, mondayOnOrBefore } from '../../domain/time/Calendar';
import { WallClock } from '../../domain/time/WallClock';
import { DayGanttPage } from '../day/DayGanttPage';
import { AppColors } from '../theme/AppColors';
import { WeekPage } from '../week/WeekPage';
import { ViewNavBar } from './ViewNavBar';

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

function dartWeekday(d: Date): number {
  const js: number = d.getDay();
  return js === 0 ? 7 : js;
}

function weekOfMonth(date: Date): number {
  const first: Date = new Date(date.getFullYear(), date.getMonth(), 1);
  return Math.floor((date.getDate() + dartWeekday(first) - 2) / 7) + 1;
}

function seedToday(repo: MemoryTaskRepository): void {
  const now: Date = new Date();
  const y: number = now.getFullYear();
  const mo: number = now.getMonth();
  const d: number = now.getDate();
  repo.upsert(new Task(
    'seed-am',
    '上午',
    WallClock.minutes(new Date(y, mo, d, 9, 0)),
    WallClock.minutes(new Date(y, mo, d, 12, 0)),
    'azure',
    0
  ));
  repo.upsert(new Task(
    'seed-overlap',
    '重叠',
    WallClock.minutes(new Date(y, mo, d, 10, 0)),
    WallClock.minutes(new Date(y, mo, d, 12, 0)),
    'azure',
    0
  ));
  repo.upsert(new Task(
    'seed-night',
    '跨夜',
    WallClock.minutes(new Date(y, mo, d, 23, 0)),
    WallClock.minutes(new Date(y, mo, d + 1, 1, 0)),
    'azure',
    0
  ));
}

@Component
export struct AppShell {
  @State anchorDate: Date = dateOnly(new Date());
  @State navIndex: number = 0;
  private repo: MemoryTaskRepository = new MemoryTaskRepository();

  aboutToAppear(): void {
    seedToday(this.repo);
  }

  private shift(delta: number): void {
    const y: number = this.anchorDate.getFullYear();
    const m: number = this.anchorDate.getMonth();
    const d: number = this.anchorDate.getDate();
    if (this.navIndex === 2) {
      this.anchorDate = new Date(y, m + delta, 1);
    } else if (this.navIndex === 1) {
      this.anchorDate = new Date(y, m, d + 7 * delta);
    } else {
      this.anchorDate = new Date(y, m, d + delta);
    }
  }

  private titleLabel(): string {
    if (this.navIndex === 2) {
      return `${this.anchorDate.getFullYear()}-${pad2(this.anchorDate.getMonth() + 1)}`;
    }
    if (this.navIndex === 1) {
      const monday: Date = mondayOnOrBefore(this.anchorDate);
      return `${monday.getMonth() + 1}月 · 第${weekOfMonth(monday)}周`;
    }
    return `${this.anchorDate.getFullYear()}-${pad2(this.anchorDate.getMonth() + 1)}-${pad2(this.anchorDate.getDate())}`;
  }

  private placeholder(): string {
    if (this.navIndex === 1) {
      return '周';
    }
    if (this.navIndex === 2) {
      return '月';
    }
    return '日';
  }

  build() {
    Column() {
      Row() {
        Text('GanttDay')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ right: 24 })
        Text('‹')
          .fontSize(28)
          .padding({ left: 8, right: 8 })
          .onClick(() => {
            this.shift(-1);
          })
        Text(this.titleLabel())
          .fontSize(16)
          .margin({ left: 4, right: 4 })
        Text('›')
          .fontSize(28)
          .padding({ left: 8, right: 8 })
          .onClick(() => {
            this.shift(1);
          })
        Text('今天')
          .fontSize(16)
          .fontColor(AppColors.AZURE)
          .padding({ left: 12, right: 8 })
          .onClick(() => {
            this.anchorDate = dateOnly(new Date());
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor(AppColors.BAR_BACKGROUND)

      if (this.navIndex === 0) {
        DayGanttPage({
          repo: this.repo,
          date: this.anchorDate
        })
          .layoutWeight(1)
          .width('100%')
      } else if (this.navIndex === 1) {
        WeekPage({
          repo: this.repo,
          date: this.anchorDate,
          onOpenDay: (day: Date) => {
            this.anchorDate = dateOnly(day);
            this.navIndex = 0;
          }
        })
          .layoutWeight(1)
          .width('100%')
      } else {
        Column() {
          Text(this.placeholder())
            .fontSize(18)
            .fontColor(AppColors.ON_SURFACE_MUTED)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }

      ViewNavBar({
        selectedIndex: this.navIndex,
        onSelect: (i: number) => {
          this.navIndex = i;
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BAR_BACKGROUND)
  }
}
