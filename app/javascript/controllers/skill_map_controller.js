import { Controller } from "@hotwired/stimulus"

// スキルマップ（管理者）。マスを押すと詳細は Turbo Frame で入れ替わるが、表は入れ替わらない。
// どのマスの詳細を見ているかが分かるよう、押したマスに選択中の印（aria-current）を付け替える。
// 「できる人が1人以下の作業だけ表示」も、ページを読み直さずに行を隠す（見立ての下書きを消さないため）
export default class extends Controller {
  static targets = ["cell", "table"]

  select(event) {
    this.cellTargets.forEach((cell) => cell.removeAttribute("aria-current"))
    event.currentTarget.setAttribute("aria-current", "true")
  }

  // 押すたびに絞り込む・元に戻す。隠すのは CSS（.skill-map-few-capable-only）の役目
  toggleFewCapable(event) {
    const button = event.currentTarget
    const pressed = button.getAttribute("aria-pressed") !== "true"
    button.setAttribute("aria-pressed", String(pressed))
    this.tableTarget.classList.toggle("skill-map-few-capable-only", pressed)
  }
}
