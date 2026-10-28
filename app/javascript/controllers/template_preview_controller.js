import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "header", "body", "footer", "previewHeader", "previewBody", "previewFooter", "previewButtons", "examples", "count", "initial" ]

  connect() {
    this.initial = {}
    if (this.hasInitialTarget) {
      try {
        this.initial = JSON.parse(this.initialTarget.textContent || "{}") || {}
      } catch (_error) {
        this.initial = {}
      }
    }
    this.render()
  }

  render() {
    this.renderExamples()
    this.paint()
  }

  paint() {
    const header = this.headerTarget.value || ""
    const body = this.bodyTarget.value || ""
    const footer = this.footerTarget.value || ""

    this.previewHeaderTarget.textContent = header
    this.previewHeaderTarget.classList.toggle("hidden", header.trim() === "")
    this.previewBodyTarget.innerHTML = this.highlight(body, "body")
    this.previewFooterTarget.textContent = footer
    this.previewFooterTarget.classList.toggle("hidden", footer.trim() === "")
    this.countTarget.textContent = `${body.length} / 1024`
    this.renderButtons()
  }

  insertVariable(event) {
    const field = event.params.field
    const input = field === "header" ? this.headerTarget : this.bodyTarget
    const next = this.indexes(input.value).reduce((max, value) => Math.max(max, value), 0) + 1
    const token = `{{${next}}}`
    const start = input.selectionStart ?? input.value.length
    const end = input.selectionEnd ?? start
    input.value = `${input.value.slice(0, start)}${token}${input.value.slice(end)}`
    const cursor = start + token.length
    input.focus()
    input.setSelectionRange(cursor, cursor)
    this.render()
  }

  renderButtons() {
    this.previewButtonsTarget.replaceChildren()
    this.buttonRows().forEach((row) => {
      if (!row.type || !row.text) return
      const line = document.createElement("div")
      line.className = "border-t border-[#eee6da] py-2 text-center text-[13px] font-medium text-[#1a6b8a]"
      line.textContent = row.text
      this.previewButtonsTarget.appendChild(line)
    })
  }

  renderExamples() {
    const needed = this.neededExamples()
    const signature = needed.map(([ key ]) => key).join("|")
    if (this.signature === signature) return
    this.signature = signature

    const existing = { ...this.initial }
    this.examplesTarget.querySelectorAll("input").forEach((input) => {
      const match = input.name.match(/\[example_values\]\[(.+)\]/)
      if (match) existing[match[1]] = input.value
    })

    this.examplesTarget.replaceChildren()
    if (needed.length === 0) {
      const note = document.createElement("p")
      note.className = "text-sm leading-relaxed text-[#6d645b]"
      note.textContent = "No variables yet. Add {{1}} where a name, order number, or date should go."
      this.examplesTarget.appendChild(note)
      return
    }

    needed.forEach(([ key, label ]) => {
      const wrap = document.createElement("label")
      wrap.className = "block"
      const caption = document.createElement("span")
      caption.className = "mb-1 block text-sm font-medium text-[#3d3832]"
      caption.textContent = `Sample for ${label}`
      const input = document.createElement("input")
      input.name = `template[example_values][${key}]`
      input.value = existing[key] || ""
      input.required = true
      input.className = "mt-1 w-full rounded-xl border border-[#e4dccf] bg-white px-3 py-2.5 text-[15px] outline-none ring-[#1f7a45] focus:ring-2"
      input.addEventListener("input", () => this.paint())
      wrap.append(caption, input)
      this.examplesTarget.appendChild(wrap)
    })
  }

  neededExamples() {
    const needed = []
    this.indexes(this.headerTarget.value).forEach((number) => needed.push([ `header_${number}`, `header {{${number}}}` ]))
    this.indexes(this.bodyTarget.value).forEach((number) => needed.push([ `body_${number}`, `body {{${number}}}` ]))
    this.buttonRows().forEach((row, index) => {
      if (row.type === "URL" && /\{\{\d+\}\}/.test(row.url)) needed.push([ `url_${index}`, `link button ${index + 1}` ])
    })
    return needed
  }

  buttonRows() {
    return Array.from(this.element.querySelectorAll("[data-button-row]")).map((row) => ({
      type: row.querySelector("[data-button-type]")?.value || "",
      text: row.querySelector("[data-button-text]")?.value || "",
      url: row.querySelector("[data-button-url]")?.value || ""
    }))
  }

  indexes(text) {
    return Array.from(text.matchAll(/\{\{(\d+)\}\}/g), (match) => Number(match[1]))
  }

  highlight(text, prefix) {
    return this.escape(text).replace(/\{\{(\d+)\}\}/g, (_full, number) => {
      const input = this.element.querySelector(`[name="template[example_values][${prefix}_${number}]"]`)
      const sample = input && input.value.trim()
      return `<span class="rounded bg-[#d9f0c7] px-1">${this.escape(sample || `{{${number}}}`)}</span>`
    }).replace(/\n/g, "<br>")
  }

  escape(text) {
    return text.replace(/[&<>"']/g, (character) => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      "\"": "&quot;",
      "'": "&#39;"
    }[character]))
  }
}
