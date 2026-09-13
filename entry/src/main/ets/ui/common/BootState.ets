export const BOOT_LOADING: string = 'loading';
export const BOOT_READY: string = 'ready';
export const BOOT_ERROR: string = 'error';

export class BootView {
  phase: string;
  showLoading: boolean;
  showShell: boolean;
  showError: boolean;
  errorPath: string;

  constructor(phase: string, errorPath: string) {
    this.phase = phase;
    this.errorPath = errorPath;
    this.showLoading = phase === BOOT_LOADING;
    this.showShell = phase === BOOT_READY;
    this.showError = phase === BOOT_ERROR;
  }
}

export function bootViewInitial(): BootView {
  return new BootView(BOOT_LOADING, '');
}

export function bootViewAfterOpen(ok: boolean, path: string): BootView {
  if (ok) {
    return new BootView(BOOT_READY, '');
  }
  return new BootView(BOOT_ERROR, path);
}
