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
- Tailwind v4 の `@apply` では、`@layer components` で自分が作ったクラス（`.badge` など）は使えない（ビルドが `Cannot apply unknown utility class` で止まる）→ ビューで `badge badge-warning` のように並べて付ける。（2026-11-02）
- 下書きの「変更を保存」と離脱確認は `unsaved-changes` コントローラ（研修画面・スキルマップで共通）→ 下書きの部分と「変更を保存」の枠（`data-unsaved-changes-target="bar" hidden`。中身は画面ごとに書く）を `data-controller="unsaved-changes"` の内側に置き、`data-unsaved-changes-confirm-message-value="<%= t('unsaved_changes.confirm_leaving') %>"` を付ける。画面のコントローラからは下書きが変わるたびに `this.dispatch("changed", { prefix: "unsaved-changes", detail: { changed: true／false } })` を送る（`prefix` がないとイベント名が送った側のコントローラ名になり届かない）。部品の中・外を問わず、画面を離れるリンク・フォームで確認する。「変更を保存」のフォームには `data: { unsaved_changes_skip: true }` を付ける（付け忘れると保存のたびに確認が出る）。Turbo Frame の中だけを入れ替えるもの（`data-turbo-frame` で枠を指定したリンクなど）は自動で確認しない。ブラウザの「戻る」・再読み込みでは確認しない（操作によって確認が出たり出なかったりしないように）。（2026-11-02）
- 上の部品を使う画面は、ビューで `<% turbo_exempts_page_from_cache %>` を呼ぶ → 呼ばないと Turbo が下書きの入った画面を覚えていて、「戻る」でそのまま出てしまう。（2026-11-02）
- 研修画面の下書きは `training-draft` コントローラ（追加・取り消し・期限）→ 「変更を保存」を押した直前（`prepare`）に hidden の入力欄を作って `PATCH /admin/training_plan` に送る。研修予定がある人の未研修のチップも `hidden` で置いておき、取り消しの下書きにしたら出す。並び順と絞り込みの区分（`data-needs-instruction`）は下書きで変えない。（2026-11-02）
- マニュアル改定編集のURLは作業ツリーと異なるため、`NavigationHelper#navigation_current?` で `admin/operations/manuals` を管理者の作業ツリータブに対応させる。保存失敗時の再表示でも同じタブを強調する。（2026-11-02）
- わたしのスキル（S-6）は左右2列の1画面 → 左（わたしのスキルの一覧）は `staff/skills/_skill_list.html.erb`、右（教える予定・教わる予定）は `staff/skills/_trainings.html.erb`。それぞれの部品の中だけを書き換えれば、もう片方とぶつからない。（2026-11-02）
- 管理者の見立ての印は、今のレベルで意味のある見立て（`Skill#assessment_meaningful?`）のときだけ出す。置き場所は使う側の CSS で決める → スキルマップは数字と印を `.skill-map-level` に入れ、印を `absolute left-full` で数字のすぐ右に付ける（幅に数えないので、印の有無で数字が真ん中からずれない）。（2026-11-05）
- スキルマップの見立ての下書きは `skill-map` コントローラが `{ スキルの ID => 見立て }` で持つ → 詳細は Turbo Frame で入れ替わるので、詳細の中に置くと別のマスを押したときに消える。詳細が入れ替わったら `assessmentTargetConnected` で下書きを選び直す（targetConnected は connect より先に呼ばれることがあるので、下書きは `initialize` で用意する）。（2026-11-02）
- `form_with` に `hidden: true` を渡しても `hidden` 属性にならない（知らないオプションは捨てられる）→ `html: { hidden: true }` で渡す。（2026-11-02）
- 「できる人○人」のバッジは、作業ツリー・作業マニュアルの見出し・研修画面のカードで `operation-badge operation-badge-warning` を使う。スキルマップの行だけ `.capable-alert`（同じ見た目）。`.capable-warning` はスキルマップの上の警告カード専用 → ほかの部品に付けると余白・背景がまざって大きくずれる。画面専用の目印には `training-capable-count` のように別のクラス名を付ける。（2026-11-03）
- 同じ茶色 `#7C2D12` のトークンが3つある（`--color-caution`・`--color-capable-alert`・`--color-operation-warning`）→ 色を変えるときは3つそろえて直す。1つにまとめるのは別の作業。（2026-11-03）
- 「できる人%{count}人」の翻訳キーが3つある（`operations.capable_count`・`admin.trainings.card.capable_count`・`admin.skill_maps.show.capable_count`）→ 文言を変えるときは3つそろえて直す。1つにまとめるのは別の作業。（2026-11-03）
- JavaScript が `<template>` を写して作る要素の文言（`aria-label` など）は、`ja.yml` に置き、`%{…}` を残したまま Stimulus の値で渡して、JavaScript で置き換える（`admin.trainings.index.plan_remove_label`・`training_due_on.date` など）。チップの「×」のように、押せる場所を示す飾りは `aria-hidden` にして、押せるのはチップ全体のままにする。（2026-11-04）
- 「変更を保存」の枠（`.save-bar`、画面に固定）が出ているあいだは、枠のすぐ外側の要素に `:has(> .save-bar:not([hidden]))` で下の余白を付けている → `main` に付けても、ビューの `pb-6` などのクラス（`@layer utilities`）が `@layer components` より必ず勝つので効かない。枠を別の場所に置くときも、枠のすぐ外側の要素が一番下までの内容を包むようにする。（2026-11-04）
- `turbo_frame_tag` で作る `<turbo-frame>` は何も指定しないと inline なので、`position: sticky` を付けても効かない → `flow-root`（または `block`）にする。`flow-root` なら中の要素の `mb-*` も枠の高さに入り、枠の背景で塗られる（下を流れる表が透けない）。スキルマップの詳細は `md` 以上だけ上に残し、狭い画面では残さない（詳細が縦に伸びて表が見えなくなるため。かわりに `autoscroll` で詳細までスクロールする）。（2026-11-04）

- 操作する人の切り替えは、「管理者（部長）／スタッフ」の立場スイッチと、スタッフ時だけ表示する `User.skill_holders` の丸い名前ボタンに分ける。各スイッチの選択中は `aria-pressed=true`。下書きの離脱確認は通常のフォーム送信で共通部品が受け持つ。（2026-11-04）

- スタッフ名のボタンは `return_to` に現在の画面を渡す。`OperatorsController` はスタッフ同士の場合だけスタッフ3画面の許可リストで戻り先を決め、作業マニュアルの `operation_id` も保つ。立場の切り替えは従来のトップへ移る。（2026-11-04）
- 管理者の見立ての名前・記号は `ja.yml` の `admin_assessments` だけに書く。マス・研修画面の名前の横・凡例の印は `AdminAssessmentsHelper#assessment_mark`（スキル）・`#assessment_icon`（見立ての値）で出す SVG アイコンで、色は `currentColor`（まわりの文字の色）→ 見立ての名前や印を画面ごとに書かない。名前を横に書く凡例では `labelled: false` で読み上げを二重にしない。（2026-11-04）
- 凡例の説明は閉じた `<details>` の中なので、Request spec（`Capybara.string`）では見えない要素として扱われる → `all(..., visible: :all)` と `text(:all)` で読む。（2026-11-04）
