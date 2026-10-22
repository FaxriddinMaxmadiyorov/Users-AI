import { Controller } from "@hotwired/stimulus"

// Select-all checkbox for the users table.
// Markup: data-controller="selection" on the form,
//   header checkbox:  data-selection-target="all"  data-action="change->selection#toggleAll"
//   row checkboxes:   data-selection-target="item" data-action="change->selection#update"
//   counter element:  data-selection-target="count"
export default class extends Controller {
  static targets = ["all", "item", "count"]

  connect() {
    this.update()
  }

  toggleAll(event) {
    const checked = event.target.checked
    this.itemTargets.forEach(checkbox => { checkbox.checked = checked })
    this.update()
  }

  update() {
    const total = this.itemTargets.length
    const selected = this.itemTargets.filter(checkbox => checkbox.checked).length

    if (this.hasAllTarget) {
      this.allTarget.checked = total > 0 && selected === total
      this.allTarget.indeterminate = selected > 0 && selected < total
    }
    if (this.hasCountTarget) {
      this.countTarget.textContent = selected > 0 ? `${selected} selected` : ""
    }
  }
}
