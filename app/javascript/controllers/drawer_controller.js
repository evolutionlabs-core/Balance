import OverlayDialogController from "lib/overlay_dialog_controller"

export default class extends OverlayDialogController {
  get transitionClasses() {
    return ["translate-x-full"]
  }
}
