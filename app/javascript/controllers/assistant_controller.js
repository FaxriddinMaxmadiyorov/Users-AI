import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["log", "input", "button"]
  static values = { url: String, usersUrl: String, filters: Object }

  connect() {
    this.history = JSON.parse(sessionStorage.getItem("assistant.history") || "[]")
    this.history.forEach(m => this.append(m.role, m.content))
  }

  async send(event) {
    event.preventDefault()
    const message = this.inputTarget.value.trim()
    if (!message) return
    this.inputTarget.value = ""
    this.append("user", message)
    this.buttonTarget.disabled = true
    const pending = this.append("assistant", "…")

    try {
      const res = await fetch(this.urlValue, {
        method: "POST",
        headers: { "Content-Type": "application/json", "Accept": "application/json",
                   "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content },
        body: JSON.stringify({ message, history: this.history.slice(-10), current_filters: this.filtersValue })
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || res.statusText)

      pending.textContent = data.answer
      this.remember("user", message)
      this.remember("assistant", data.answer)

      if (data.command?.type === "navigate") Turbo.visit(this.buildUrl(data.command.filters))
    } catch (e) {
      pending.textContent = "Error: " + e.message
    } finally {
      this.buttonTarget.disabled = false
      this.inputTarget.focus()
    }
  }

  buildUrl(filters) {
    const params = new URLSearchParams()
    Object.entries(filters || {}).forEach(([k, v]) => {
      if (Array.isArray(v)) params.set(k, v.join(","))
      else if (v !== null && v !== undefined && v !== "") params.set(k, v)
    })
    const qs = params.toString()
    return qs ? `${this.usersUrlValue}?${qs}` : this.usersUrlValue
  }

  remember(role, content) {
    this.history = [...this.history, { role, content }].slice(-20)
    sessionStorage.setItem("assistant.history", JSON.stringify(this.history))
  }

  append(role, text) {
    const div = document.createElement("div")
    div.className = `msg ${role}`
    div.textContent = text
    this.logTarget.appendChild(div)
    this.logTarget.scrollTop = this.logTarget.scrollHeight
    return div
  }
}
