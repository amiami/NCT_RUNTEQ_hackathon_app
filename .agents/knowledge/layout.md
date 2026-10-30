# 共通レイアウト

- 共通ヘッダーは `shared/header`、全7画面はadmin/staffの名前空間で区別する。立場別リンクは画面移動のみで認可・ユーザー選択ではない。操作ユーザー機能と接続するときに両方を確認する。（2026-10-30）
- 合意により管理者スキルマップとスタッフ2タブの件数バッジは仮表示を使う。header/tabsへskill_map_count・training_count・unread_countを渡し、省略・nilは99、0は0のまま。実件数の集計と操作ユーザー選択は別途接続する。（2026-10-30）
- ルートはスタッフの作業マニュアル。`navigation_current?` で `/` と `/staff/operations` を同じ選択タブとして扱う。凡例の概要は常時表示し、詳細だけdetailsで開閉する。（2026-10-30）
- モックの文字組みは `Noto Sans JP, system-ui, sans-serif` と `line-height: normal`。Tailwindのtext-sm/text-xsは既定の行間を持つため、共通部品ではnormalを明示する。フォントの読込はlayouts/headにまとめる。（2026-10-30）
- 各画面はadmin/staff配下の専用ERBをRails標準の暗黙renderで表示する。h1には立場と画面名を記載し、共通ヘッダーはapplicationレイアウトから呼ぶ。（2026-10-31）
