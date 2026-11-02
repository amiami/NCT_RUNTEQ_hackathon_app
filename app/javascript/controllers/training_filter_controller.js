import { Controller } from "@hotwired/stimulus"

// 研修画面の絞り込み（すべて／指示が必要／指示済み）。
// 画面を開き直さずにカードの表示だけを切り替える（開き直すと、#61 の下書きが消えるため）
export default class extends Controller {
  static targets = ["button", "card", "empty"]

  select(event) {
    const filter = event.currentTarget.dataset.filter

    this.buttonTargets.forEach((button) => {
      const active = button === event.currentTarget
      button.classList.toggle("filter-chip-active", active)
      button.setAttribute("aria-pressed", active)
    })

    let shown = 0
    this.cardTargets.forEach((card) => {
      const needsInstruction = card.dataset.needsInstruction === "true"
      const visible = filter === "all" ||
        (filter === "needs_instruction" && needsInstruction) ||
        (filter === "assigned" && !needsInstruction)
      card.hidden = !visible
      if (visible) shown += 1
    })

    if (this.hasEmptyTarget) this.emptyTarget.hidden = shown > 0
  }
}
