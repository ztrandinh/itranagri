"use client";
/** ConfirmDialog: thay window.confirm() native. Có tiêu đề, mô tả, nút hủy/xác nhận, biến thể nguy hiểm.
 *  Dùng qua hook useConfirm() để gọi kiểu await: if (await confirm({...})) { ... } */
import { useCallback, useState } from "react";
import { Modal } from "./Modal";

type ConfirmOpts = { title: string; message?: string; confirmText?: string; cancelText?: string; danger?: boolean };

export function useConfirm() {
  const [state, setState] = useState<(ConfirmOpts & { resolve: (v: boolean) => void }) | null>(null);

  const confirm = useCallback((opts: ConfirmOpts) => new Promise<boolean>((resolve) => setState({ ...opts, resolve })), []);

  const close = useCallback((v: boolean) => {
    setState((s) => { s?.resolve(v); return null; });
  }, []);

  const element = state ? (
    <Modal open onClose={() => close(false)} title={state.title}>
      {state.message && <p className="text-slate-600 mb-4">{state.message}</p>}
      <div className="flex gap-2 justify-end">
        <button className="btn-secondary !py-2.5 !px-4 !text-base" onClick={() => close(false)}>
          {state.cancelText ?? "Hủy"}
        </button>
        <button
          className={`${state.danger ? "btn-danger" : "btn-primary"} !py-2.5 !px-4 !text-base`}
          onClick={() => close(true)}
        >
          {state.confirmText ?? "Xác nhận"}
        </button>
      </div>
    </Modal>
  ) : null;

  return { confirm, confirmElement: element };
}
