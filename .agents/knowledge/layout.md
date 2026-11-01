# 共通レイアウト

- 共通ヘッダーは `shared/header`、全7画面はadmin/staffの名前空間で区別する。立場別リンクは画面移動のみで認可・ユーザー選択ではない。操作ユーザー機能と接続するときに両方を確認する。（2026-10-30）
- 合意により管理者スキルマップとスタッフ2タブの件数バッジは仮表示を使う。header/tabsへskill_map_count・training_count・unread_countを渡し、省略・nilは99、0は0のまま。実件数の集計と操作ユーザー選択は別途接続する。（2026-10-30）
- 凡例の概要は常時表示し、詳細だけdetailsで開閉する。（2026-10-30）
- `/` は `HomesController#show` が立場で振り分けてリダイレクトする（部長 → `/admin/operations`、スタッフ → `/staff/operations`）。`Admin::BaseController` の振り分けを使うと注意が出るので使わない。`/` 自体は画面を持たないので、タブの強調は `current_page?` だけで足りる。（2026-11-01）
- モックの文字組みは `Noto Sans JP, system-ui, sans-serif` と `line-height: normal`。Tailwindのtext-sm/text-xsは既定の行間を持つため、共通部品ではnormalを明示する。フォントの読込はlayouts/headにまとめる。（2026-10-30）
- 各画面はadmin/staff配下の専用ERBをRails標準の暗黙renderで表示する。h1には立場と画面名を記載し、共通ヘッダーはapplicationレイアウトから呼ぶ。（2026-10-31）
- 通知件数は `NavigationHelper#navigation_counts` の返すハッシュを共通レイアウトからheaderへ渡す。現在は空ハッシュ。実集計の接続はこのメソッドで行う。全画面の見出しは `.page-title` で共通化する。（2026-10-31）
- 立場別リンクは `navigation.roles`、見出しとブラウザタイトルの立場付き表記は `page_titles` をja.ymlで管理する。`page` に既存のタブ名の翻訳を渡す。（2026-10-31）
- 管理者スキルマップの通知件数バッジは表示する。仮表示の規則をspec/screensに明記し、実集計の対象・条件は別途定義する。（2026-10-31）
- 操作する人（部長／スタッフ）は `PATCH /operator`（`OperatorsController#update`）で切り替え、`session[:user_id]` に持つ。`current_user` は選んだスタッフ、未選択・いなくなったときは部長（管理者）、ユーザーが0人なら nil。管理者の画面は `Admin::BaseController` でスタッフのとき弾く。ヘッダーは `NavigationHelper#operator_switch` を呼ぶので、view spec では `operator_switch` をスタブする。（2026-11-01）
