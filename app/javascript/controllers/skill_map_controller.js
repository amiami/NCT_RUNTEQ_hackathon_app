import { Controller } from "@hotwired/stimulus"

// スキルマップ（管理者）。マスを押すと詳細は Turbo Frame で入れ替わるが、表は入れ替わらない。
// どのマスの詳細を見ているかが分かるよう、押したマスに選択中の印（aria-current）を付け替える。
// 「できる人が1人以下の作業だけ表示」も、ページを読み直さずに行を隠す（見立ての下書きを消さないため）。
// 見立ての下書き：詳細で選んだ見立ては保存せず、ここで持つ（詳細は入れ替わるので、詳細の中に置くと別のマスを押したときに消える）。
// 下書きが変わるたびに、共通部品（unsaved-changes）へ「変更あり／なし」を知らせ、「変更を保存（n件）」の件数を書き換える。
// 「変更を保存」の直前に hidden の入力欄にする
export default class extends Controller {
  static targets = ["cell", "table", "assessment", "fields", "saveLabel"]
  static values = { saveLabel: String }

  // 詳細の targetConnected は connect より先に呼ばれることがあるので、下書きは initialize で用意する
  initialize() {
    this.drafts = new Map() // スキルの ID（文字列） => 選んだ見立て（"" は「なし」）
  }

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

  // 詳細で見立てを選ぶと下書きに入れる。元の見立てを選び直したら、そのマスの下書きを取り消す
  chooseAssessment(event) {
    const { skillId, originalAssessment } = event.target.closest("fieldset").dataset
    if (event.target.value === originalAssessment) {
      this.drafts.delete(skillId)
    } else {
      this.drafts.set(skillId, event.target.value)
    }
    this.refresh()
  }

  // 詳細が入れ替わったら（下書きのあるマスに戻ってきたとき）、下書きの見立てを選び直す
  assessmentTargetConnected(choices) {
    const draft = this.drafts.get(choices.dataset.skillId)
    if (draft === undefined) return

    choices.querySelectorAll("input[type='radio']").forEach((radio) => { radio.checked = radio.value === draft })
  }

  // 「変更を保存」を押した直前に、下書きを assessments[スキルの ID]=見立て の hidden の入力欄にする
  prepare() {
    const inputs = [...this.drafts].map(([skillId, assessment]) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = `assessments[${skillId}]`
      input.value = assessment
      return input
    })
    this.fieldsTarget.replaceChildren(...inputs)
  }

  // 下書きのあるマスに未保存の見た目を付け、件数を書き換えて、共通部品に「変更あり／なし」を知らせる
  refresh() {
    this.cellTargets.forEach((cell) => {
      cell.classList.toggle("skill-map-cell-draft", this.drafts.has(cell.dataset.skillId))
    })
    this.saveLabelTarget.textContent = this.saveLabelValue.replace("%{count}", this.drafts.size)
    this.dispatch("changed", { prefix: "unsaved-changes", detail: { changed: this.drafts.size > 0 } })
  }
}
