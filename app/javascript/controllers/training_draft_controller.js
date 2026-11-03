import { Controller } from "@hotwired/stimulus"

// 研修画面（S-3）の下書き。「変更を保存」を押すまで DB には入れず、画面の中だけで持つ。
//   - 追加：未研修の人を選んで教える人を押す（誰も選んでいなければ、カードに残っている未研修の人全員。1人1件）
//   - 取り消し：保存済みの予定（カードの研修予定・右の一覧の「取り消す」）を押す。もう一度押すと取り消しをやめる
//   - 期限：カードの日付を変える（その作業の予定すべての期限になる）
// 下書きが変わるたびに、共通部品（unsaved-changes）へ「変更あり／なし」を知らせる。
// 変更ありにするのは、追加・保存済みの予定の取り消し・予定がある作業の期限の変更だけ（予定がない作業の日付だけなら変更なし）。
// カードの並び順と絞り込みの区分は、開いたときのまま変えない
export default class extends Controller {
  static targets = ["card", "planTemplate", "form", "fields"]
  static values = { dueLabel: String, noDueLabel: String, cancelLabel: String, undoCancelLabel: String }

  connect() {
    this.additions = [] // { operationId, trainerId, traineeId, element }
    this.cancellations = new Set() // 取り消す保存済みの予定の id（文字列）
    this.notify()
  }

  // 未研修のチップを押すと、選択状態を切り替える
  toggleTrainee(event) {
    const chip = event.currentTarget
    this.select(chip, chip.getAttribute("aria-pressed") !== "true")
  }

  // 教える人を押すと、選んだ未研修の人（誰も選んでいなければ残っている全員）との予定を1人1件ずつ下書きに入れる
  assign(event) {
    const trainer = event.currentTarget
    const card = this.cardOf(trainer)
    const available = this.traineeChips(card).filter((chip) => !chip.hidden)
    const selected = available.filter((chip) => chip.getAttribute("aria-pressed") === "true")
    const picked = selected.length > 0 ? selected : available
    if (picked.length === 0) return

    picked.forEach((chip) => {
      const element = this.planTemplateTarget.content.firstElementChild.cloneNode(true)
      element.querySelector(".plan-chip-names").textContent = `${trainer.dataset.trainerName} → ${chip.dataset.traineeName}`
      card.querySelector(".plan-list").append(element)
      this.additions.push({
        operationId: card.dataset.operationId,
        trainerId: trainer.dataset.trainerId,
        traineeId: chip.dataset.traineeId,
        element
      })
      this.select(chip, false)
      chip.hidden = true
    })
    this.refresh(card)
  }

  // 下書きで追加した予定をもう一度押すと消し、その人を未研修に戻す
  removeDraft(event) {
    const element = event.currentTarget
    const addition = this.additions.find((item) => item.element === element)
    if (!addition) return

    const card = this.cardOf(element)
    this.removeAddition(addition)
    this.traineeChip(card, addition.traineeId)?.removeAttribute("hidden")
    this.refresh(card)
  }

  // 保存済みの予定を取り消す下書きにする。もう一度押すと取り消しをやめる。
  // 取り消した人は未研修に戻すので、同じ保存で別の教える人に頼み直せる
  toggleCancel(event) {
    const trainingId = event.currentTarget.dataset.trainingId
    const cancelling = !this.cancellations.has(trainingId)
    if (cancelling) {
      this.cancellations.add(trainingId)
    } else {
      this.cancellations.delete(trainingId)
    }

    const planChip = this.element.querySelector(`.plan-chip[data-training-id="${trainingId}"]`)
    if (planChip) {
      planChip.classList.toggle("plan-chip-cancelled", cancelling)
      planChip.setAttribute("aria-pressed", cancelling)
    }
    this.element.querySelectorAll(`.assigned-training[data-training-id="${trainingId}"]`).forEach((item) => {
      item.classList.toggle("assigned-training-cancelled", cancelling)
      const button = item.querySelector("button[data-training-id]")
      button.textContent = cancelling ? this.undoCancelLabelValue : this.cancelLabelValue
      button.setAttribute("aria-pressed", cancelling)
    })

    const card = planChip && this.cardOf(planChip)
    if (card) {
      const traineeId = planChip.dataset.traineeId
      const chip = this.traineeChip(card, traineeId)
      if (!cancelling) {
        // 取り消しをやめたら、その人の下書きの予定（頼み直し）も消す（同じ人の未完了の予定は1件まで）
        this.additions
          .filter((item) => item.operationId === card.dataset.operationId && item.traineeId === traineeId)
          .forEach((item) => this.removeAddition(item))
      }
      if (chip) {
        this.select(chip, false)
        chip.hidden = !cancelling
      }
      this.refresh(card)
    } else {
      this.notify()
    }
  }

  // カードの日付を変えると、その作業の予定（保存済み・下書き）の期限の表示も変える
  changeDue(event) {
    this.refresh(this.cardOf(event.currentTarget))
  }

  // 「変更を保存」で送る直前に、下書きを hidden の入力欄にする（#60 の PATCH /admin/training_plan の形）
  prepare() {
    const fields = this.fieldsTarget
    fields.replaceChildren()
    const add = (name, value) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = `training_plan${name}`
      input.value = value ?? ""
      fields.append(input)
    }

    this.additions.forEach((item) => {
      add("[additions][][operation_id]", item.operationId)
      add("[additions][][trainer_id]", item.trainerId)
      add("[additions][][trainee_id]", item.traineeId)
      add("[additions][][due_on]", this.dateField(this.cardById(item.operationId)).value)
    })
    this.cancellations.forEach((id) => add("[cancellations][]", id))
    this.cardTargets.filter((card) => this.dueChanged(card)).forEach((card) => {
      add("[due_dates][][operation_id]", card.dataset.operationId)
      add("[due_dates][][due_on]", this.dateField(card).value)
    })
  }

  // --- 表示と「変更あり／なし」 ---

  refresh(card) {
    const label = this.dueLabel(this.dateField(card).value)
    card.querySelectorAll(".plan-chip .plan-chip-due").forEach((due) => { due.textContent = label })

    const trainees = this.traineeChips(card).filter((chip) => !chip.hidden)
    card.querySelector('[data-empty-for="trainees"]').hidden = trainees.length > 0
    card.querySelector('[data-empty-for="plans"]').hidden = card.querySelectorAll(".plan-chip").length > 0

    this.notify()
  }

  notify() {
    this.dispatch("changed", { prefix: "unsaved-changes", detail: { changed: this.changed } })
  }

  get changed() {
    return this.additions.length > 0 ||
      this.cancellations.size > 0 ||
      this.cardTargets.some((card) => this.dueChanged(card) && this.hasPlans(card))
  }

  // 予定がある作業か（保存済みで取り消していないもの＋下書きで追加したもの）
  hasPlans(card) {
    const saved = [...card.querySelectorAll(".plan-chip[data-training-id]")]
      .filter((chip) => !this.cancellations.has(chip.dataset.trainingId))
    const drafts = this.additions.filter((item) => item.operationId === card.dataset.operationId)
    return saved.length > 0 || drafts.length > 0
  }

  dueChanged(card) {
    const field = this.dateField(card)
    return field.value !== (field.dataset.initialValue || "")
  }

  dueLabel(value) {
    if (!value) return this.noDueLabelValue
    return this.dueLabelValue.replace("%{date}", value.replaceAll("-", "/"))
  }

  // --- 小さな道具 ---

  removeAddition(addition) {
    addition.element.remove()
    this.additions = this.additions.filter((item) => item !== addition)
  }

  select(chip, on) {
    chip.setAttribute("aria-pressed", on)
    chip.classList.toggle("trainee-chip-selected", on)
  }

  cardOf(element) {
    return element.closest('[data-training-draft-target~="card"]')
  }

  cardById(operationId) {
    return this.cardTargets.find((card) => card.dataset.operationId === operationId)
  }

  dateField(card) {
    return card.querySelector('input[type="date"]')
  }

  traineeChips(card) {
    return [...card.querySelectorAll(".trainee-chip")]
  }

  traineeChip(card, traineeId) {
    return card.querySelector(`.trainee-chip[data-trainee-id="${traineeId}"]`)
  }
}
