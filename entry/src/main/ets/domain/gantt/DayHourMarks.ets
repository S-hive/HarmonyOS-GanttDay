import { WallClock } from '../time/WallClock';

export class DayHourMarkInfo {
  label: string = '';
  emphasized: boolean = false;
  isDayBoundary: boolean = false;
}

export class DateBadgeBox {
  x: number = 0;
  y: number = 0;
  w: number = 0;
  h: number = 0;
}

export function skipBodyHourTick(minutesFromDay0: number): boolean {
  return minutesFromDay0 > 0 && minutesFromDay0 % WallClock.MINUTES_PER_DAY === 0;
}

export function layoutDateBadge(
  textX: number,
  textWidth: number,
  textHeight: number,
  headerHeight: number,
  pad: number
): DateBadgeBox {
  const box: DateBadgeBox = new DateBadgeBox();
  box.w = textWidth + pad * 2;
  box.h = textHeight + pad * 2;
  const maxH: number = headerHeight - 2;
  if (maxH > 0 && box.h > maxH) {
    box.h = maxH;
  }
  box.y = (headerHeight - box.h) / 2;
  if (box.y < 1) {
    box.y = 1;
  }
  if (box.y + box.h > headerHeight - 1) {
    box.y = headerHeight - 1 - box.h;
    if (box.y < 1) {
      box.y = 1;
      box.h = headerHeight - 2;
    }
  }
  box.x = textX - pad;
  return box;
}

export function dayHourMark(pageDay0: number, minutesFromDay0: number): DayHourMarkInfo {
  const t: number = pageDay0 + minutesFromDay0;
  const dt: Date = WallClock.dateTime(t);
  const page: Date = WallClock.dateTime(pageDay0);
  const otherDay: boolean = dt.getFullYear() !== page.getFullYear() ||
    dt.getMonth() !== page.getMonth() ||
    dt.getDate() !== page.getDate();
  const info: DayHourMarkInfo = new DayHourMarkInfo();
  info.isDayBoundary = minutesFromDay0 > 0 && otherDay && dt.getHours() === 0;
  if (info.isDayBoundary) {
    info.label = `${dt.getMonth() + 1}/${dt.getDate()}`;
  } else {
    info.label = `${dt.getHours()}:00`;
  }
  const hour: number = dt.getHours();
  info.emphasized = minutesFromDay0 === 0 || info.isDayBoundary || hour % 6 === 0;
  return info;
}
