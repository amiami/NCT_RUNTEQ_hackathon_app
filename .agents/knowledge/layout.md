# 共通レイアウト

- 共通ヘッダーは `shared/header`、全7画面はadmin/staffの名前空間で区別する。立場別リンクは画面移動のみで認可・ユーザー選択ではない。操作ユーザー機能と接続するときに両方を確認する。（2026-10-30）
- 凡例の概要は常時表示し、詳細だけdetailsで開閉する。（2026-10-30）
- `/` は `HomesController#show` が立場で振り分けてリダイレクトする（部長 → `/admin/operations`、スタッフ → `/staff/operations`）。`Admin::BaseController` の振り分けを使うと注意が出るので使わない。`/` 自体は画面を持たないので、タブの強調は `current_page?` だけで足りる。（2026-11-01）
- モックの文字組みは `Noto Sans JP, system-ui, sans-serif` と `line-height: normal`。Tailwindのtext-sm/text-xsは既定の行間を持つため、共通部品ではnormalを明示する。フォントの読込はlayouts/headにまとめる。（2026-10-30）
- 各画面はadmin/staff配下の専用ERBをRails標準の暗黙renderで表示する。h1には立場と画面名を記載するが、画面には出さない（読み上げ用に `.page-title` の `sr-only` で隠す。h1は消さない）。共通ヘッダーはapplicationレイアウトから呼ぶ。（2026-11-01）
- 全画面の見出しは `.page-title` で共通化する。（2026-10-31）
- 立場別リンクは `navigation.roles`、見出しとブラウザタイトルの立場付き表記は `page_titles` をja.ymlで管理する。`page` に既存のタブ名の翻訳を渡す。（2026-10-31）
- タブの件数は `NavigationHelper#navigation_counts` が `current_user` から数え、共通レイアウトから header → tabs へ渡す。スタッフは `training_count`・`unread_count`、部長は `skill_map_count` だけ。0件・nil はバッジを出さない（仮表示の99は廃止）。件数を足すときは、問い合わせの回数が一定になるスコープで数える（`spec/helpers/navigation_helper_spec.rb` で回数を確かめている）。（2026-11-01）
- 操作する人（部長／スタッフ）は `PATCH /operator`（`OperatorsController#update`）で切り替え、`session[:user_id]` に持つ。`current_user` は選んだスタッフ、未選択・いなくなったときは部長（管理者）、ユーザーが0人なら nil。管理者の画面は `Admin::BaseController` でスタッフのとき弾く。ヘッダーは `NavigationHelper#operator_switch` を呼ぶので、view spec では `operator_switch` をスタブする。（2026-11-01）

- マニュアル改定編集のURLは作業ツリーと異なるため、`NavigationHelper#navigation_current?` で `admin/operations/manuals` を管理者の作業ツリータブに対応させる。保存失敗時の再表示でも同じタブを強調する。（2026-11-02）
- 下書きの「変更を保存」と離脱確認は `unsaved-changes` コントローラ（研修画面・スキルマップで共通）→ 下書きの部分と「変更を保存」の枠（`data-unsaved-changes-target="bar" hidden`。中身は画面ごとに書く）を `data-controller="unsaved-changes"` の内側に置き、`data-unsaved-changes-confirm-message-value="<%= t('unsaved_changes.confirm_leaving') %>"` を付ける。画面のコントローラからは下書きが変わるたびに `this.dispatch("changed", { prefix: "unsaved-changes", detail: { changed: true／false } })` を送る（`prefix` がないとイベント名が送った側のコントローラ名になり届かない）。部品の中・外を問わず、画面を離れるリンク・フォームで確認する。「変更を保存」のフォームには `data: { unsaved_changes_skip: true }` を付ける（付け忘れると保存のたびに確認が出る）。Turbo Frame の中だけを入れ替えるもの（`data-turbo-frame` で枠を指定したリンクなど）は自動で確認しない。ブラウザの「戻る」・再読み込みでは確認しない（操作によって確認が出たり出なかったりしないように）。（2026-11-02）
- 上の部品を使う画面は、ビューで `<% turbo_exempts_page_from_cache %>` を呼ぶ → 呼ばないと Turbo が下書きの入った画面を覚えていて、「戻る」でそのまま出てしまう。（2026-11-02）
