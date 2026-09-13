import { MemoryTaskRepository } from '../../data/MemoryTaskRepository';
import { TaskRepository } from '../../platform/TaskRepository';
import { dateOnly, mondayOnOrBefore } from '../../domain/time/Calendar';
import { DayGanttPage } from '../day/DayGanttPage';
import { AppColors } from '../theme/AppColors';
import { MonthPage } from '../month/MonthPage';
import { WeekPage } from '../week/WeekPage';
import { TitleBar } from './TitleBar';
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

@Component
export struct AppShell {
  @State anchorDate: Date = dateOnly(new Date());
  @State navIndex: number = 0;
  repo: TaskRepository = new MemoryTaskRepository();

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

  build() {
    Column() {
      if (this.navIndex !== 0) {
        TitleBar({
          dateLabel: this.titleLabel(),
          onPrev: () => {
            this.shift(-1);
          },
          onNext: () => {
            this.shift(1);
          },
          onToday: () => {
            this.anchorDate = dateOnly(new Date());
          }
        })
      }

      Column() {
        if (this.navIndex === 0) {
          DayGanttPage({
            repo: this.repo,
            date: this.anchorDate,
            onShift: (delta: number) => {
              this.shift(delta);
            },
            onGoToday: () => {
              this.anchorDate = dateOnly(new Date());
            }
          })
            .width('100%')
            .height('100%')
        } else if (this.navIndex === 1) {
          WeekPage({
            repo: this.repo,
            date: this.anchorDate,
            onOpenDay: (day: Date) => {
              this.anchorDate = dateOnly(day);
              this.navIndex = 0;
            }
          })
            .width('100%')
            .height('100%')
        } else {
          MonthPage({
            repo: this.repo,
            date: this.anchorDate,
            onOpenDay: (day: Date) => {
              this.anchorDate = dateOnly(day);
              this.navIndex = 0;
            }
          })
            .width('100%')
            .height('100%')
        }
      }
      .layoutWeight(1)
      .width('100%')

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
