import { Context } from '@kit.AbilityKit';
import { relationalStore, ValuesBucket } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { FactorySwatches } from '../domain/gantt/FactorySwatches';
import { ColorSwatch } from '../domain/models/ColorSwatch';

export class DatabaseOpenError {
  message: string;
  path: string;

  constructor(message: string, path: string) {
    this.message = message;
    this.path = path;
  }
}

export class AppDatabase {
  static readonly SCHEMA_VERSION: number = 2;
  static readonly FILE_NAME: string = 'gantday.db';
  static readonly CORRUPT_PREFIX: string = 'gantday.db.corrupt-';

  static rdbDirectory(context: Context): string {
    return `${context.databaseDir}/rdb`;
  }

  static databasePath(context: Context): string {
    return `${AppDatabase.rdbDirectory(context)}/${AppDatabase.FILE_NAME}`;
  }

  static async openOrRepair(context: Context): Promise<relationalStore.RdbStore> {
    const config: relationalStore.StoreConfig = {
      name: AppDatabase.FILE_NAME,
      securityLevel: relationalStore.SecurityLevel.S1,
      allowRebuild: false
    };
    let store: relationalStore.RdbStore;
    try {
      store = await relationalStore.getRdbStore(context, config);
    } catch (firstErr) {
      const backupOrDbPath: string = await AppDatabase.renameCorrupt(context);
      return Promise.reject(new DatabaseOpenError(
        AppDatabase.errorMessage(firstErr as BusinessError),
        backupOrDbPath
      ));
    }
    try {
      await AppDatabase.applySchema(store);
      await AppDatabase.seed(store);
      if (store.version < AppDatabase.SCHEMA_VERSION) {
        store.version = AppDatabase.SCHEMA_VERSION;
      }
      return store;
    } catch (schemaErr) {
      return Promise.reject(new DatabaseOpenError(
        AppDatabase.errorMessage(schemaErr as BusinessError),
        AppDatabase.databasePath(context)
      ));
    }
  }

  static async applySchema(store: relationalStore.RdbStore): Promise<void> {
    await store.executeSql(
      'CREATE TABLE IF NOT EXISTS color_swatch (' +
        'id TEXT PRIMARY KEY, ' +
        'name TEXT NOT NULL, ' +
        'argb INTEGER NOT NULL, ' +
        'hue INTEGER NOT NULL, ' +
        'saturation REAL NOT NULL, ' +
        'lightness REAL NOT NULL, ' +
        'is_default INTEGER NOT NULL, ' +
        'sort_order INTEGER NOT NULL, ' +
        'slate INTEGER NOT NULL DEFAULT 0' +
        ')'
    );
    await store.executeSql(
      'CREATE TABLE IF NOT EXISTS task (' +
        'id TEXT PRIMARY KEY, ' +
        'title TEXT NOT NULL, ' +
        'planned_start INTEGER NOT NULL, ' +
        'planned_end INTEGER NOT NULL, ' +
        'actual_start INTEGER, ' +
        'actual_end INTEGER, ' +
        'is_done INTEGER NOT NULL DEFAULT 0, ' +
        'primary_tag_id TEXT, ' +
        'auto_swatch_id TEXT NOT NULL, ' +
        'override_swatch_id TEXT, ' +
        'notes TEXT, ' +
        'created_at INTEGER NOT NULL' +
        ')'
    );
    await store.executeSql(
      'CREATE INDEX IF NOT EXISTS idx_task_planned_start ON task(planned_start)'
    );
    await store.executeSql(
      'CREATE INDEX IF NOT EXISTS idx_task_planned_end ON task(planned_end)'
    );
    await store.executeSql(
      'CREATE TABLE IF NOT EXISTS tag (' +
        'id TEXT PRIMARY KEY, ' +
        'name TEXT NOT NULL UNIQUE, ' +
        'swatch_id TEXT NOT NULL' +
        ')'
    );
    await store.executeSql(
      'CREATE TABLE IF NOT EXISTS task_tag (' +
        'task_id TEXT NOT NULL, ' +
        'tag_id TEXT NOT NULL, ' +
        'PRIMARY KEY (task_id, tag_id)' +
        ')'
    );
    await store.executeSql(
      'CREATE TABLE IF NOT EXISTS setting (' +
        'key TEXT PRIMARY KEY, ' +
        'value TEXT NOT NULL' +
        ')'
    );
  }

  static async seed(store: relationalStore.RdbStore): Promise<void> {
    const swatches: ColorSwatch[] = FactorySwatches.ALL;
    for (let i = 0; i < swatches.length; i++) {
      await AppDatabase.insertSwatch(store, swatches[i]);
    }
    await AppDatabase.insertSetting(store, 'visibleStartHour', '8');
    await AppDatabase.insertSetting(store, 'visibleEndHour', '22');
    await AppDatabase.insertSetting(store, 'urgencyWindowDays', '7');
  }

  static async insertSwatch(store: relationalStore.RdbStore, swatch: ColorSwatch): Promise<void> {
    const row: ValuesBucket = {
      'id': swatch.id,
      'name': swatch.name,
      'argb': swatch.argb,
      'hue': swatch.hue,
      'saturation': swatch.saturation,
      'lightness': swatch.lightness,
      'is_default': swatch.isDefault ? 1 : 0,
      'sort_order': swatch.sortOrder,
      'slate': swatch.slate ? 1 : 0
    };
    await store.insert('color_swatch', row, relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
  }

  static async insertSetting(store: relationalStore.RdbStore, key: string, value: string): Promise<void> {
    const row: ValuesBucket = {
      'key': key,
      'value': value
    };
    await store.insert('setting', row, relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
  }

  static async renameCorrupt(context: Context): Promise<string> {
    const path: string = AppDatabase.resolveExistingDbPath(context);
    if (path.length === 0) {
      return AppDatabase.databasePath(context);
    }
    const dest: string = `${AppDatabase.parentDir(path)}/${AppDatabase.CORRUPT_PREFIX}${AppDatabase.timeStamp()}`;
    try {
      await fileIo.rename(path, dest);
    } catch (e) {
      return Promise.reject(new DatabaseOpenError(
        AppDatabase.errorMessage(e as BusinessError),
        path
      ));
    }
    AppDatabase.removeSidecar(`${path}-wal`);
    AppDatabase.removeSidecar(`${path}-shm`);
    return dest;
  }

  static resolveExistingDbPath(context: Context): string {
    const inRdb: string = AppDatabase.databasePath(context);
    if (AppDatabase.fileExists(inRdb)) {
      return inRdb;
    }
    const flat: string = `${context.databaseDir}/${AppDatabase.FILE_NAME}`;
    if (AppDatabase.fileExists(flat)) {
      return flat;
    }
    return '';
  }

  static fileExists(path: string): boolean {
    try {
      return fileIo.accessSync(path);
    } catch (e) {
      return false;
    }
  }

  static removeSidecar(path: string): void {
    if (!AppDatabase.fileExists(path)) {
      return;
    }
    try {
      fileIo.unlinkSync(path);
    } catch (e) {
      return;
    }
  }

  static parentDir(path: string): string {
    const idx: number = path.lastIndexOf('/');
    if (idx <= 0) {
      return path;
    }
    return path.substring(0, idx);
  }

  static timeStamp(): string {
    const d: Date = new Date();
    return `${d.getFullYear()}${AppDatabase.pad2(d.getMonth() + 1)}${AppDatabase.pad2(d.getDate())}` +
      `${AppDatabase.pad2(d.getHours())}${AppDatabase.pad2(d.getMinutes())}${AppDatabase.pad2(d.getSeconds())}`;
  }

  static pad2(n: number): string {
    if (n < 10) {
      return `0${n}`;
    }
    return `${n}`;
  }

  static errorMessage(e: BusinessError): string {
    return `${e.code}:${e.message}`;
  }
}
