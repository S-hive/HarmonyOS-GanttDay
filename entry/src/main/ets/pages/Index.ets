import { common } from '@kit.AbilityKit';
import { AppDatabase, DatabaseOpenError } from '../data/AppDatabase';
import { RdbTaskRepository } from '../data/RdbTaskRepository';
import { TaskRepository } from '../platform/TaskRepository';
import { BOOT_ERROR, BOOT_LOADING, BOOT_READY, BootView, bootViewAfterOpen } from '../ui/common/BootState';
import { DbErrorScreen } from '../ui/common/DbErrorScreen';
import { consumeActualEditBack } from '../domain/gantt/ActualEdit';
import { consumeDeleteVeilBack } from '../ui/common/DeleteVeilOverlay';
import { consumeDrawerSystemBack } from '../ui/common/SideDrawer';
import { AppShell } from '../ui/shell/AppShell';

@Entry
@Component
struct Index {
  @State phase: string = BOOT_LOADING;
  @State errorPath: string = '';
  private repo: TaskRepository | null = null;

  aboutToAppear(): void {
    this.openDatabase();
  }

  onBackPress(): boolean {
    if (consumeDeleteVeilBack()) {
      return true;
    }
    if (consumeDrawerSystemBack()) {
      return true;
    }
    return consumeActualEditBack();
  }

  private applyBoot(ok: boolean, path: string): void {
    const view: BootView = bootViewAfterOpen(ok, path);
    this.phase = view.phase;
    this.errorPath = view.errorPath;
  }

  private async openDatabase(): Promise<void> {
    this.phase = BOOT_LOADING;
    this.errorPath = '';
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      const store = await AppDatabase.openOrRepair(ctx);
      this.repo = new RdbTaskRepository(store);
      this.applyBoot(true, '');
    } catch (e) {
      let path: string = AppDatabase.databasePath(ctx);
      if (e instanceof DatabaseOpenError) {
        path = e.path;
      }
      this.applyBoot(false, path);
    }
  }

  build() {
    Column() {
      if (this.phase === BOOT_READY && this.repo !== null) {
        AppShell({ repo: this.repo })
          .width('100%')
          .height('100%')
      } else if (this.phase === BOOT_ERROR) {
        DbErrorScreen({
          path: this.errorPath,
          onRebuild: () => {
            this.openDatabase();
          }
        })
      } else {
        Column()
          .width('100%')
          .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
