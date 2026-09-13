import { describe, it, expect } from '@ohos/hypium';
import {
  BOOT_ERROR,
  BOOT_LOADING,
  BOOT_READY,
  BootView,
  bootViewAfterOpen,
  bootViewInitial
} from '../../../main/ets/ui/common/BootState';
import { DB_CORRUPT_HINT, DB_REBUILD_LABEL, dbErrorExplainText } from '../../../main/ets/ui/common/DbErrorScreen';

export default function bootStateTest() {
  describe('BootState', () => {
    it('starts_loading_without_shell', 0, () => {
      const view: BootView = bootViewInitial();
      expect(view.phase).assertEqual(BOOT_LOADING);
      expect(view.showLoading).assertTrue();
      expect(view.showShell).assertFalse();
      expect(view.showError).assertFalse();
    });

    it('open_success_shows_shell', 0, () => {
      const view: BootView = bootViewAfterOpen(true, '');
      expect(view.phase).assertEqual(BOOT_READY);
      expect(view.showShell).assertTrue();
      expect(view.showLoading).assertFalse();
      expect(view.showError).assertFalse();
    });

    it('open_failure_shows_error_path', 0, () => {
      const view: BootView = bootViewAfterOpen(false, '/data/gantday.db');
      expect(view.phase).assertEqual(BOOT_ERROR);
      expect(view.showError).assertTrue();
      expect(view.showShell).assertFalse();
      expect(view.errorPath).assertEqual('/data/gantday.db');
    });

    it('rebuild_success_returns_to_shell', 0, () => {
      const view: BootView = bootViewAfterOpen(true, '');
      expect(view.showShell).assertTrue();
    });

    it('error_copy_names_corrupt_file_and_rebuild', 0, () => {
      expect(DB_REBUILD_LABEL).assertEqual('重建');
      expect(DB_CORRUPT_HINT).assertEqual('gantday.db.corrupt-…');
      expect(dbErrorExplainText().indexOf('gantday.db.corrupt-…') >= 0).assertTrue();
    });
  });
}
