import OverlayDialogController from "lib/overlay_dialog_controller"

export default class extends OverlayDialogController {
  get transitionClasses() {
    return ["opacity-0", "translate-y-4", "sm:translate-y-2", "scale-[0.98]"]
  }
}
