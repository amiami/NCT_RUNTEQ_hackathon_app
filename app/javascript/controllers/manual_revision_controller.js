import { Controller } from "@hotwired/stimulus"

// 保存条件はサーバーでも検証する。ここでは入力に合わせてボタンを切り替える。
export default class extends Controller {
  static targets = ["body", "memo", "submit"]
  static values = { originalBody: String }

  connect() {
    this.refresh()
  }

  refresh() {
    const memoPresent = this.memoTarget.value.trim().length > 0
    const bodyChanged = !this.hasBodyTarget || (
      this.bodyTarget.value.trim().length > 0 &&
      this.normalize(this.bodyTarget.value) !== this.normalize(this.originalBodyValue)
    )
    this.submitTarget.disabled = !(memoPresent && bodyChanged)
  }

  normalize(value) {
    return value.replace(/\r\n?/g, "\n")
  }
}
