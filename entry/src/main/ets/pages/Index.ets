import { AppShell } from '../ui/shell/AppShell';

@Entry
@Component
struct Index {
  build() {
    Column() {
      AppShell()
    }
    .width('100%')
    .height('100%')
  }
}
