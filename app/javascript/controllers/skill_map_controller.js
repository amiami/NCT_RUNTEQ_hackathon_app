import { Controller } from "@hotwired/stimulus"

// スキルマップ（管理者）。マスを押すと詳細は Turbo Frame で入れ替わるが、表は入れ替わらない。
// どのマスの詳細を見ているかが分かるよう、押したマスに選択中の印（aria-current）を付け替える
export default class extends Controller {
  static targets = ["cell"]

  select(event) {
    this.cellTargets.forEach((cell) => cell.removeAttribute("aria-current"))
    event.currentTarget.setAttribute("aria-current", "true")
  }
}
