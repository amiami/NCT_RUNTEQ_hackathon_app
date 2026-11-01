# モデル

- `Operation#capable_count` は作業ごとに COUNT を出すため、一覧で呼ぶと N+1 になる → 一覧では `Skill.capable_counts`（`{ operation_id => 人数 }`、いない作業は含まないので `fetch(id, 0)`）を使う。（2026-10-31）
- `Skill#unread?` は `operation.manual` をたどる → Skill の一覧で使うときは `includes(operation: :manual)` で先に読み込む。（2026-10-31）
- 「できる人」の条件（スキルを持つ人のうちレベル4。◇・▼も含む）は `Skill.capable` にまとめてある → 条件を書き直さず、このスコープを使う。（2026-10-31）
- `Training` の作成時の条件チェック（教える人・教わる人）は1件ごとに `Skill` のスコープで `exists?` を2回出す → 「変更を保存」でまとめて作るときはクエリが件数に比例する。件数が増えたら候補のスキルを先にまとめて読み込む。（2026-10-31）
- 研修の候補の条件は `Skill.trainer_candidates`（教える人。並び順つき、管理者は含まない）と `Skill.training_targets`（レベル0・1と▼）にまとめてある → Training の作成時のチェックも研修画面（`TrainingBoard.cards`）もこれを使う。条件を書き直さない。（2026-11-01）
- 見立てを画面に出すかは値ではなく `Skill#assessment_meaningful?` で決める（4▲・4▽・3◇は出さない）。教える人の候補になるかは値で決まるので別物。（2026-11-01）
- `where.not(admin_assessment: :needs_training)` は見立てなし（NULL）の行も外してしまう → 入れたい値を `[ nil, … ]` で並べる。（2026-11-01）
- `DISTINCT ON` を外側のクエリに直接書くと `.count`・`.reorder` がエラーになる → `Training.latest_done` のように id を選ぶ部分をサブクエリに閉じ込めて `where(id: …)` にする。（2026-11-01）
- 研修予定の「変更を保存」は `TrainingPlan` でまとめて反映する → 1件ずつ `Training.create!`・`destroy!` を呼ばない。失敗の理由は `errors`（作業と教わる人の名前つき）に入る。（2026-11-01）
- 期限の一括変更は `Training.unfinished.where(operation_id:).update_all` で行う → `update_all` はバリデーションも `updated_at` の自動更新も通らないので、`updated_at` は自分で入れる。期限の変更以外には使わない。（2026-11-01）
- DB のユニークインデックス違反（`RecordNotUnique`）はバリデーションのエラーとは別の例外 → 2回押しがほぼ同時に届く場合に備えて、`TrainingPlan` では個別に受け止めている。（2026-11-01）
