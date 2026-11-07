import assert from "node:assert/strict"
import { beforeEach, describe, it } from "node:test"

const { default: EmbeddedSignupController } = await import(
  "../../app/javascript/controllers/embedded_signup_controller.js"
)

const SDK_URL = "https://connect.facebook.net/en_US/sdk.js"

function element(tag) {
  return {
    tag,
    async: false,
    defer: false,
    crossOrigin: "",
    src: "",
    method: "",
    action: "",
    type: "",
    name: "",
    value: "",
    dataset: {},
    children: [],
    appendChild(child) {
      this.children.push(child)
    },
    submit() {
      submitted.push(this)
    }
  }
}

let submitted
let listeners
let elements

function installDom() {
  submitted = []
  listeners = []
  elements = new Map()

  function create(tag) {
    const node = element(tag)
    let id = ""
    Object.defineProperty(node, "id", {
      get() {
        return id
      },
      set(value) {
        id = value
        if (value) elements.set(value, node)
      }
    })
    node.submit = function submit() {
      submitted.push(node)
    }
    return node
  }

  const head = create("head")
  const body = create("body")
  globalThis.window = {
    addEventListener(type, handler) {
      listeners.push([ type, handler ])
    },
    removeEventListener() {},
    FB: undefined,
    fbAsyncInit: undefined
  }
  globalThis.document = {
    head,
    body,
    getElementById(id) {
      return elements.get(id) || null
    },
    createElement: create,
    querySelector(selector) {
      if (selector === 'meta[name="csrf-token"]') return { content: "csrf-test" }
      return null
    }
  }
}

function controller() {
  const instance = new EmbeddedSignupController()
  instance.appIdValue = "1234567890"
  instance.configIdValue = "987654321"
  instance.versionValue = "v26.0"
  instance.element = { dataset: {} }
  instance.connect()
  return instance
}

function deliver(origin, payload) {
  const handler = listeners.find(([ type ]) => type === "message")[1]
  handler({
    origin,
    data: typeof payload === "string" ? payload : JSON.stringify(payload)
  })
}

function fieldsOf(form) {
  return Object.fromEntries(form.children.map((input) => [ input.name, input.value ]))
}

describe("Embedded Signup controller", () => {
  beforeEach(() => {
    installDom()
  })

  it("loads the Facebook SDK and initializes it with the app id and Graph version", () => {
    controller()

    const scripts = document.head.children.filter((node) => node.tag === "script")
    assert.equal(scripts.length, 1)
    assert.equal(scripts[0].src, SDK_URL)
    assert.equal(scripts[0].id, "facebook-jssdk")
    assert.equal(scripts[0].async, true)
    assert.equal(scripts[0].defer, true)
    assert.equal(scripts[0].crossOrigin, "anonymous")

    window.FB = { init(options) { this.options = options } }
    window.fbAsyncInit()

    assert.equal(window.FB.options.appId, "1234567890")
    assert.equal(window.FB.options.version, "v26.0")
    assert.equal(window.FB.options.autoLogAppEvents, true)
    assert.equal(window.FB.options.xfbml, false)
  })

  it("does not insert a second SDK script when one is already on the page", () => {
    const existing = document.createElement("script")
    existing.id = "facebook-jssdk"
    document.head.appendChild(existing)

    controller()

    assert.equal(document.head.children.filter((node) => node.id === "facebook-jssdk").length, 1)
  })

  it("asks Facebook to log in with the Embedded Signup configuration", async () => {
    const login = []
    window.FB = {
      init() {},
      login(callback, options) {
        login.push(options)
        callback({ authResponse: { code: "good_CODE-1" } })
      }
    }

    const signup = controller()
    await signup.start()

    assert.equal(login.length, 1)
    assert.deepEqual(login[0], {
      config_id: "987654321",
      response_type: "code",
      override_default_response_type: true,
      extras: { setup: {}, sessionInfoVersion: "3" }
    })
    assert.equal(signup.code, "good_CODE-1")
  })

  it("posts the code and account ids when signup finishes", () => {
    const signup = controller()
    signup.code = "good_CODE-1"

    deliver("https://www.facebook.com", {
      type: "WA_EMBEDDED_SIGNUP",
      event: "FINISH",
      data: { waba_id: "111", phone_number_id: "222" }
    })

    assert.equal(submitted.length, 1)
    assert.equal(submitted[0].method, "post")
    assert.equal(submitted[0].action, "/settings/embedded_signup")
    assert.deepEqual(fieldsOf(submitted[0]), {
      authenticity_token: "csrf-test",
      code: "good_CODE-1",
      waba_id: "111",
      phone_number_id: "222"
    })
  })

  it("does not post when the customer cancels", () => {
    const signup = controller()
    signup.code = "good_CODE-1"

    deliver("https://www.facebook.com", { type: "WA_EMBEDDED_SIGNUP", event: "CANCEL" })

    assert.equal(signup.code, null)
    assert.equal(submitted.length, 0)
  })

  it("ignores a message from another origin", () => {
    const signup = controller()
    signup.code = "good_CODE-1"

    deliver("https://evil.example", {
      type: "WA_EMBEDDED_SIGNUP",
      event: "FINISH",
      data: { waba_id: "111", phone_number_id: "222" }
    })

    assert.equal(signup.code, "good_CODE-1")
    assert.equal(submitted.length, 0)
  })

  it("ignores a finish message until Facebook has returned a code", () => {
    controller()

    deliver("https://web.facebook.com", {
      type: "WA_EMBEDDED_SIGNUP",
      event: "FINISH",
      data: { waba_id: "111", phone_number_id: "222" }
    })

    assert.equal(submitted.length, 0)
  })

  it("ignores a message that is not JSON", () => {
    const signup = controller()
    signup.code = "good_CODE-1"

    assert.doesNotThrow(() => deliver("https://www.facebook.com", "{"))
    assert.equal(submitted.length, 0)
  })

  it("tells the customer when the Facebook SDK cannot be loaded", async () => {
    const signup = controller()
    const script = document.head.children.find((node) => node.tag === "script")
    script.onerror()

    await signup.start()

    assert.equal(signup.element.dataset.signupError, "Could not load the Facebook signup window")
    assert.equal(submitted.length, 0)
  })
})
