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
- 「教え終わった」は `TrainingCompletion.new(training:, by: current_user).save` → 予定の完了・レベル2・記録・確認した版・▼→▽ を1つのトランザクションで行う。押せるのは教える人だけ（サービスで確かめる）なので、画面側でボタンを出す条件も「教える人のとき」にそろえる。（2026-11-02）
- 2回押しで二重に完了しないよう、`TrainingCompletion` は予定を `lock!` で読み直してから完了済みかを見る → 画面を開いたときに読み込んだ古い予定のまま渡されても、DB の今の状態で判断できる。（2026-11-02）
- 「改定後に未確認」をまとめて数えるときは `Skill.unread`（`unread?` と同じ条件の SQL）を使う → `skills.count(&:unread?)` は1件ずつ `operation.manual` を読んで N+1 になる。（2026-11-01）
- できる人が1人以下の作業の数は `Operation.few_capable_count` → `Skill.capable_counts` は0人の作業を含まないので、そのまま `count { <= 1 }` すると0人の作業を数え落とす。（2026-11-01）
- その人の教える予定・教わる予定は `Training.involving(user)`（未完了だけなら `.unfinished` と組み合わせる）。（2026-11-01）
- 研修画面の右の一覧は `TrainingBoard.assigned_trainings`（未完了の予定すべて＋教わる人のスキル）→ カード（`TrainingBoard.cards`）は対象の人がいる作業だけなので、カードの予定から作らない（申告で対象から外れた作業の予定が消えてしまう）。（2026-11-02）
- 見立ての記号は `TrainingsHelper#assessment_mark(skill)` で出す → `assessment_meaningful?` が false なら何も出さない。管理者の画面だけで使い、スタッフの画面では呼ばない。（2026-11-02）
