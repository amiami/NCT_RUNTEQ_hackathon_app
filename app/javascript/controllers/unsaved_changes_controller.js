import { Controller } from "@hotwired/stimulus"

// 下書きの「変更を保存」と、保存しないまま移るときの確認（研修画面・スキルマップで共通に使う）。
// 何が変わったかは使う画面が判断し、部品の中から次のイベントで「変更あり／なし」を知らせる。
//   this.dispatch("changed", { prefix: "unsaved-changes", detail: { changed: true } })
// 変更ありのときだけ「変更を保存」の枠（bar ターゲット）を出し、リンク・フォームでこの画面から移ろうとしたら確認する
// （部品の中・外を問わない。部品の中で画面を読み直すフォームでも下書きは消えるため）。
// 次のものは画面を離れないので確認しない
//   - data-unsaved-changes-skip を付けたリンク・フォーム（「変更を保存」など）
//   - Turbo Frame の中だけを入れ替えるリンク・フォーム（data-turbo-frame で枠を指定したもの。スキルマップのマスなど）
// ブラウザの「戻る」・再読み込み・タブを閉じる操作では確認しない（どの場合も下書きは消える）
export default class extends Controller {
  static targets = ["bar"]
  static values = { confirmMessage: String }

  connect() {
    this.changed = false
    this.update = this.update.bind(this)
    this.confirmLeaving = this.confirmLeaving.bind(this)
    this.element.addEventListener("unsaved-changes:changed", this.update)
    // Turbo より先に止められるよう、ページ全体のクリックと送信をキャプチャで受け取る
    document.addEventListener("click", this.confirmLeaving, true)
    document.addEventListener("submit", this.confirmLeaving, true)
    this.render()
  }

  disconnect() {
    this.element.removeEventListener("unsaved-changes:changed", this.update)
    document.removeEventListener("click", this.confirmLeaving, true)
    document.removeEventListener("submit", this.confirmLeaving, true)
  }

  update(event) {
    this.changed = event.detail?.changed === true
    this.render()
  }

  render() {
    this.barTargets.forEach((bar) => { bar.hidden = !this.changed })
  }

  confirmLeaving(event) {
    if (!this.changed) return
    const element = event.type === "submit" ? event.target : this.leavingLink(event)
    if (!element || this.staysOnPage(element, event.submitter)) return

    if (window.confirm(this.confirmMessageValue)) {
      // 続けたら下書きは捨てる（移った先から戻っても復元しない）。
      // data-turbo-method のリンクのように、クリックと送信の両方で呼ばれる操作で確認が2回出ないよう false に戻す。
      // そのため、OK のあと画面が移らなかったとき（入力エラーなど）は、次は確認が出ない。いまの画面にそういう操作はない
      this.changed = false
    } else {
      event.preventDefault()
      event.stopImmediatePropagation()
    }
  }

  // この画面から移るリンク（なければ null）。新しいタブで開く操作と、同じ画面の中の移動（#…）は除く
  leavingLink(event) {
    const link = event.target.closest("a[href]")
    if (!link) return null
    if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return null
    if (link.target === "_blank" || link.hasAttribute("download")) return null

    const url = new URL(link.href, window.location.href)
    const samePageHash = url.pathname === window.location.pathname && url.search === window.location.search && url.hash
    return samePageHash ? null : link
  }

  // 画面を離れないリンク・フォームか。印（data-unsaved-changes-skip）が付いたもの（送信ボタンに付けてもよい）と、
  // Turbo Frame の中だけを入れ替えるもの（data-turbo-frame が _top 以外か、<turbo-frame> の中で枠の外を指定していないもの）
  staysOnPage(element, submitter) {
    if (element.closest("[data-unsaved-changes-skip]") || submitter?.closest("[data-unsaved-changes-skip]")) return true

    const frame = submitter?.dataset.turboFrame || element.closest("[data-turbo-frame]")?.dataset.turboFrame
    if (frame) return frame !== "_top"

    const parentFrame = element.closest("turbo-frame")
    return Boolean(parentFrame) && parentFrame.getAttribute("target") !== "_top"
  }
}
