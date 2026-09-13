import { describe, it, expect } from '@ohos/hypium';
import { layoutWeekSlots, WeekSlot } from '../../../main/ets/domain/week/WeekColumnLayout';
import { Task } from '../../../main/ets/domain/models/Task';
import { WallClock } from '../../../main/ets/domain/time/WallClock';

function task(id: string, start: Date, end: Date, title: string = 't'): Task {
  return new Task(
    id,
    title,
    WallClock.minutes(start),
    WallClock.minutes(end),
    'azure',
    WallClock.minutes(start)
  );
}

function closeTo(actual: number, expected: number): boolean {
  return Math.abs(actual - expected) < 1e-9;
}

function slotById(slots: WeekSlot[], id: string): WeekSlot {
  for (let i = 0; i < slots.length; i++) {
    if (slots[i].taskId === id) {
      return slots[i];
    }
  }
  throw new Error(`slot not found: ${id}`);
}

export default function weekColumnLayoutTest() {
  describe('WeekColumnLayout', () => {
    const monday: Date = new Date(2026, 7, 3);

    it('places_same_day_task_with_vertical_fractions', 0, () => {
      const slots: WeekSlot[] = layoutWeekSlots(monday, [
        task('a', new Date(2026, 7, 5, 9, 30), new Date(2026, 7, 5, 12), '拍摄')
      ]);
      expect(slots.length).assertEqual(1);
      expect(slots[0].dayIndex).assertEqual(2);
      expect(closeTo(slots[0].topFrac, 9.5 / 24)).assertEqual(true);
      expect(closeTo(slots[0].heightFrac, 2.5 / 24)).assertEqual(true);
      expect(slots[0].columnIndex).assertEqual(0);
      expect(slots[0].columnCount).assertEqual(1);
    });

    it('splits_multi_day_task_across_days', 0, () => {
      const slots: WeekSlot[] = layoutWeekSlots(monday, [
        task('b', new Date(2026, 7, 4, 18), new Date(2026, 7, 6, 10))
      ]);
      expect(slots.length).assertEqual(3);
      expect(slots[0].dayIndex).assertEqual(1);
      expect(slots[1].dayIndex).assertEqual(2);
      expect(slots[2].dayIndex).assertEqual(3);
      expect(closeTo(slots[0].topFrac, 18 / 24)).assertEqual(true);
      expect(closeTo(slots[0].heightFrac, 6 / 24)).assertEqual(true);
      expect(closeTo(slots[1].topFrac, 0)).assertEqual(true);
      expect(closeTo(slots[1].heightFrac, 1)).assertEqual(true);
      expect(closeTo(slots[2].topFrac, 0)).assertEqual(true);
      expect(closeTo(slots[2].heightFrac, 10 / 24)).assertEqual(true);
    });

    it('overlapping_tasks_share_side_by_side_columns', 0, () => {
      const slots: WeekSlot[] = layoutWeekSlots(monday, [
        task('a', new Date(2026, 7, 5, 9, 30), new Date(2026, 7, 5, 12), '拍摄'),
        task('b', new Date(2026, 7, 5, 10), new Date(2026, 7, 5, 12), '面试'),
        task('c', new Date(2026, 7, 5, 13, 15), new Date(2026, 7, 5, 14, 30), '剪辑')
      ]);
      const wed: WeekSlot[] = [];
      for (let i = 0; i < slots.length; i++) {
        if (slots[i].dayIndex === 2) {
          wed.push(slots[i]);
        }
      }
      expect(wed.length).assertEqual(3);
      const a: WeekSlot = slotById(wed, 'a');
      const b: WeekSlot = slotById(wed, 'b');
      const c: WeekSlot = slotById(wed, 'c');
      expect(a.columnCount).assertEqual(2);
      expect(b.columnCount).assertEqual(2);
      const pair: string = `${a.columnIndex},${b.columnIndex}`;
      expect(pair === '0,1' || pair === '1,0').assertEqual(true);
      expect(c.columnCount).assertEqual(1);
      expect(c.columnIndex).assertEqual(0);
    });
  });
}
