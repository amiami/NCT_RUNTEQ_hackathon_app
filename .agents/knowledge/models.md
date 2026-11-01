# モデル

- `Operation#capable_count` は作業ごとに COUNT を出すため、一覧で呼ぶと N+1 になる → 一覧では `Skill.capable_counts`（`{ operation_id => 人数 }`、いない作業は含まないので `fetch(id, 0)`）を使う。（2026-10-31）
- `Skill#unread?` は `operation.manual` をたどる → Skill の一覧で使うときは `includes(operation: :manual)` で先に読み込む。（2026-10-31）
- 「できる人」の条件（スキルを持つ人のうちレベル4。◇・▼も含む）は `Skill.capable` にまとめてある → 条件を書き直さず、このスコープを使う。（2026-10-31）
- `Training` の作成時の条件チェック（教える人・教わる人）は1件ごとに `Skill.find_by` を2回出す → 「変更を保存」でまとめて作るときはクエリが件数に比例する。件数が増えたら候補のスキルを先にまとめて読み込む。（2026-10-31）
- 管理者の見立ての保存は `Skills::AssessmentUpdate`（`{ スキルの ID => 見立て }`、`""` は「なし」）を使う → 付けられるレベルは `ASSIGNABLE_LEVELS` にまとめてあり、値が変わるマスだけ確かめる。画面からは `PATCH /skills/assessment` に `assessments[ID]=値` で送る（キーが決まらないので `params.expect(assessments: {})` で受け取る）。（2026-11-01）
