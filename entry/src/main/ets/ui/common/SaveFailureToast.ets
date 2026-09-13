import { promptAction } from '@kit.ArkUI';
import { EmptyTitleError } from '../../platform/TaskRepository';

export function shouldToastSaveFailure(err: Object): boolean {
  return !(err instanceof EmptyTitleError);
}

export function toastSaveFailure(): void {
  promptAction.showToast({ message: '保存失败' });
}

export function persistOrToast(op: Promise<void>, showToast?: () => void): Promise<void> {
  const toast: () => void = showToast === undefined ? toastSaveFailure : showToast;
  return op.catch((err: Object) => {
    if (shouldToastSaveFailure(err)) {
      toast();
    }
  });
}
