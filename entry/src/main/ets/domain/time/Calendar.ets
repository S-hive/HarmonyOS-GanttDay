export function dateOnly(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

export function mondayOnOrBefore(d: Date): Date {
  const day: Date = dateOnly(d);
  const jsDay: number = day.getDay();
  const back: number = jsDay === 0 ? 6 : jsDay - 1;
  return new Date(day.getFullYear(), day.getMonth(), day.getDate() - back);
}
