# モデル

- `Operation#capable_count` は作業ごとに COUNT を出すため、一覧で呼ぶと N+1 になる → 一覧では `Skill.capable_counts`（`{ operation_id => 人数 }`、いない作業は含まないので `fetch(id, 0)`）を使う。（2026-10-31）
- `Skill#unread?` は `operation.manual` をたどる → Skill の一覧で使うときは `includes(operation: :manual)` で先に読み込む。（2026-10-31）
- 「できる人」の条件（スキルを持つ人のうちレベル4。◇・▼も含む）は `Skill.capable` にまとめてある → 条件を書き直さず、このスコープを使う。（2026-10-31）
