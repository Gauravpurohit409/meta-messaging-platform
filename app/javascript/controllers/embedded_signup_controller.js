import { Controller } from "@hotwired/stimulus"

const SDK_URL = "https://connect.facebook.net/en_US/sdk.js"
const SDK_ELEMENT_ID = "facebook-jssdk"

export default class extends Controller {
  static values = {
    appId: String,
    configId: String,
    version: { type: String, default: "v26.0" }
  }

  connect() {
    this.code = null
    this.onMetaMessage = (event) => this.receive(event)
    window.addEventListener("message", this.onMetaMessage)
    this.prepareSdk()
  }

  disconnect() {
    window.removeEventListener("message", this.onMetaMessage)
  }

  start() {
    return this.prepareSdk().then(() => {
      window.FB.login((response) => {
        this.code = response && response.authResponse && response.authResponse.code
      }, {
        config_id: this.configIdValue,
        response_type: "code",
        override_default_response_type: true,
        extras: { setup: {}, sessionInfoVersion: "3" }
      })
    }).catch(() => {
      const message = "Could not load the Facebook signup window"
      this.element.dataset.signupError = message
      this.element.textContent = message
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

  prepareSdk() {
    if (this.sdkReady) return this.sdkReady

    this.sdkReady = new Promise((resolve, reject) => {
      const boot = () => {
        window.FB.init({
          appId: this.appIdValue,
          autoLogAppEvents: true,
          xfbml: false,
          version: this.versionValue || "v26.0"
        })
        resolve()
      }

      if (window.FB) {
        boot()
        return
      }

      window.fbAsyncInit = boot
      if (document.getElementById(SDK_ELEMENT_ID)) return

      const script = document.createElement("script")
      script.id = SDK_ELEMENT_ID
      script.async = true
      script.defer = true
      script.crossOrigin = "anonymous"
      script.src = SDK_URL
      script.onerror = () => reject(new Error("Facebook SDK failed to load"))
      document.head.appendChild(script)
    })

    return this.sdkReady
  }
}
