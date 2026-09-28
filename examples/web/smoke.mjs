import assert from "node:assert/strict"

class Element {
  constructor(value = "") {
    this.value = value
    this.textContent = ""
    this.dataset = {}
    this.listeners = new Map()
  }

  addEventListener(name, callback) {
    this.listeners.set(name, callback)
  }

  click() {
    this.listeners.get("click")?.()
  }
}

const elements = new Map([
  ["profile", new Element("standard")],
  ["password-length", new Element("16")],
  ["pin-length", new Element("6")],
  ["generate-password", new Element()],
  ["generate-pin", new Element()],
  ["generate-passphrase", new Element()],
  ["copy", new Element()],
  ["output", new Element()],
  ["entropy", new Element()],
  ["status", new Element()],
])

globalThis.document = {
  getElementById(id) {
    return elements.get(id)
  },
}

Object.defineProperty(globalThis, "navigator", {
  value: { clipboard: { writeText() {} } },
  configurable: true,
})

await import("../../_build/js/release/build/zhangsan2000w-art/moonbit-securegen/cmd/web/web.js")

elements.get("generate-password").click()
assert.equal(elements.get("output").textContent.length, 16)
assert.match(elements.get("entropy").textContent, /bits/)
assert.equal(elements.get("status").dataset.kind, "ok")

elements.get("generate-pin").click()
assert.match(elements.get("output").textContent, /^\d{6}$/)

elements.get("generate-passphrase").click()
assert.equal(elements.get("output").textContent.split("-").length, 4)

console.log("web smoke: password, PIN, and passphrase flows passed")
