import { AppColors } from '../theme/AppColors';

export const DB_REBUILD_LABEL: string = '重建';
export const DB_CORRUPT_HINT: string = 'gantday.db.corrupt-…';

export function dbErrorExplainText(): string {
  return `数据库已损坏，原文件已改名为 ${DB_CORRUPT_HINT}`;
}

@Component
export struct DbErrorScreen {
  @Prop path: string = '';
  onRebuild: () => void = (): void => {
  };

  build() {
    Column() {
      Text(dbErrorExplainText())
        .fontSize(16)
        .fontColor(Color.Black)
        .textAlign(TextAlign.Center)
        .margin({ left: 24, right: 24, bottom: 12 })
      Text(this.path)
        .fontSize(13)
        .fontColor(AppColors.ON_SURFACE_MUTED)
        .textAlign(TextAlign.Center)
        .margin({ left: 24, right: 24, bottom: 24 })
      Button(DB_REBUILD_LABEL)
        .onClick(() => {
          this.onRebuild();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppColors.BAR_BACKGROUND)
  }
}
