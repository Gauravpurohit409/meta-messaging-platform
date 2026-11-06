import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { appId: String, configId: String }

  connect() {
    this.code = null
    this.onMetaMessage = (event) => this.receive(event)
    window.addEventListener("message", this.onMetaMessage)
  }

  disconnect() {
    window.removeEventListener("message", this.onMetaMessage)
  }

  start() {
    window.FB.login((response) => {
      this.code = response && response.authResponse && response.authResponse.code
    }, {
      config_id: this.configIdValue,
      response_type: "code",
      override_default_response_type: true,
      extras: { setup: {}, sessionInfoVersion: "3" }
    })
  }

  receive(event) {
    if (!event.origin.endsWith("facebook.com")) return

    let data
    try {
      data = JSON.parse(event.data)
    } catch (_error) {
      return
    }
    if (!data || data.type !== "WA_EMBEDDED_SIGNUP") return
    if (data.event === "CANCEL") {
      this.code = null
      return
    }
    if (data.event === "FINISH") {
      const info = data.data || {}
      const waba_id = info.waba_id
      const phone_number_id = info.phone_number_id
      if (!this.code || !waba_id || !phone_number_id) return
      this.submit(waba_id, phone_number_id)
    }
  }

  submit(wabaId, phoneNumberId) {
    const token = document.querySelector('meta[name="csrf-token"]').content
    const form = document.createElement("form")
    form.method = "post"
    form.action = "/settings/embedded_signup"
    const fields = {
      authenticity_token: token,
      code: this.code,
      waba_id: wabaId,
      phone_number_id: phoneNumberId
    }
    Object.entries(fields).forEach(([name, value]) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = name
      input.value = value
      form.appendChild(input)
    })
    document.body.appendChild(form)
    form.submit()
  }
}
