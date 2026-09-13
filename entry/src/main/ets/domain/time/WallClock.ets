export class WallClock {
  static readonly MINUTES_PER_DAY: number = 24 * 60;

  static minutes(local: Date): number {
    const utcMs = Date.UTC(
      local.getFullYear(),
      local.getMonth(),
      local.getDate(),
      local.getHours(),
      local.getMinutes()
    );
    return Math.floor(utcMs / 60000);
  }

  static dateTime(m: number): Date {
    const utc = new Date(m * 60000);
    return new Date(
      utc.getUTCFullYear(),
      utc.getUTCMonth(),
      utc.getUTCDate(),
      utc.getUTCHours(),
      utc.getUTCMinutes()
    );
  }

  static dayStart(any: number): number {
    return any - (any % WallClock.MINUTES_PER_DAY);
  }

  static dayEndExclusive(any: number): number {
    return WallClock.dayStart(any) + WallClock.MINUTES_PER_DAY;
  }
}
