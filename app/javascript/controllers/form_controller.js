import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit(event) {
    const form = event.target.form
    if (form.checkValidity()) form.requestSubmit()
  }
}
