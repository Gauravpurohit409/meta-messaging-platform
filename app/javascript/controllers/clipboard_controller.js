import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "source", "label" ]

  copy() {
    const value = this.sourceTarget.value || this.sourceTarget.textContent
    navigator.clipboard.writeText(value.trim()).then(() => {
      const original = this.labelTarget.textContent
      this.labelTarget.textContent = "Copied"
      window.setTimeout(() => { this.labelTarget.textContent = original }, 1600)
    })
  }
}
