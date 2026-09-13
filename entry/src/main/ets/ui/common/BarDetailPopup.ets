import { formatBarTimeLabel } from '../day/CreateTaskPopup';
import { WallClock } from '../../domain/time/WallClock';

export const BAR_DETAIL_MAX_W: number = 320;
export const BAR_DETAIL_GAP: number = 6;
export const BAR_DETAIL_MARGIN: number = 8;
export const BAR_DETAIL_ESTIMATED_H: number = 64;
export const BAR_DETAIL_ESTIMATED_W: number = 220;

const WEEKDAY_NAMES: string[] = ['日', '一', '二', '三', '四', '五', '六'];

export class PopupOrigin {
  x: number;
  y: number;

  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }
}

function clamp(value: number, min: number, max: number): number {
  if (max < min) {
    return min;
  }
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}

export function formatBarHoverDate(day: Date): string {
  return `${day.getMonth() + 1}月${day.getDate()}日(星期${WEEKDAY_NAMES[day.getDay()]})`;
}

export function formatBarHoverMeta(start: number, end: number, focusDay: Date | null = null): string {
  const day: Date = focusDay !== null ? focusDay : WallClock.dateTime(WallClock.dayStart(start));
  return `${formatBarHoverDate(day)}·${formatBarTimeLabel(start, end)}`;
}

export function formatBarHoverDetail(
  title: string,
  start: number,
  end: number,
  focusDay: Date | null = null
): string {
  return `${title}\n${formatBarHoverMeta(start, end, focusDay)}`;
}

export function barDetailPopupOrigin(
  anchorLeft: number,
  anchorTop: number,
  anchorBottom: number,
  viewportW: number,
  viewportH: number,
  popupW: number,
  popupH: number
): PopupOrigin {
  let x: number = anchorLeft;
  let y: number = anchorBottom + BAR_DETAIL_GAP;
  if (y + popupH > viewportH - BAR_DETAIL_MARGIN) {
    y = anchorTop - popupH - BAR_DETAIL_GAP;
  }
  x = clamp(x, BAR_DETAIL_MARGIN, viewportW - popupW - BAR_DETAIL_MARGIN);
  y = clamp(y, BAR_DETAIL_MARGIN, viewportH - popupH - BAR_DETAIL_MARGIN);
  return new PopupOrigin(x, y);
}

@Component
export struct BarDetailPopup {
  @Prop title: string = '';
  @Prop meta: string = '';

  build() {
    Column() {
      Text(this.title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.meta)
        .fontSize(12)
        .fontColor('#E6FFFFFF')
        .margin({ top: 2 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .constraintSize({ maxWidth: BAR_DETAIL_MAX_W })
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor('#2C2C2E')
    .borderRadius(8)
    .shadow({ radius: 8, color: 0x40000000, offsetX: 0, offsetY: 2 })
  }
}
