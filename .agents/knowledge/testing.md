# テスト

- サブエージェントでのチェックはユーザーの明示依頼がある場合だけ行う。使用する場合も GitHub の最新 Issue と関連 Issue を読み、AC ごとに実装・テスト・画面確認・未確認を照合する。チェック欄の状態だけで完了と判断しない。（2026-11-01）
- `/` は立場別画面へのリダイレクト → 振り分けと遷移後の表示は `root_spec`、本文と作業選択は `/admin/operations`・`/staff/operations` の Request spec で検証する。（2026-11-01）

- `build(:training)` は作成時の条件を満たすスキル（教える人はレベル4、教わる人はレベル0）をその作業に自動で作る → `operation: nil` や別の作業を渡すときは、`trainer:`・`trainee:` やスキルを自分で用意する。（2026-10-31）
- `validates :trainee_id, uniqueness:` のエラーは `trainee` ではなく `trainee_id` に付く → `ja.yml` の翻訳キー（`errors.models.training.attributes.trainee_id.taken`）と属性名も `trainee_id` で書く。（2026-10-31）
- `bin/rails runner` で動きを確かめるときに `create!` すると開発用 DB にデータが残る → `ActiveRecord::Base.transaction do … raise ActiveRecord::Rollback end` の中で実行する（`raise` をトランザクションの外に書かない）。（2026-10-31）
- seeds の過去の完了済み研修は、現在のレベルでは依頼時の候補条件（作成時バリデーション）を満たさない → 固定の完了履歴だけ検証を省いて投入し、相手・状態・日付は `spec/seeds/seeds_spec.rb` で検証する。通常の研修作成には使わない。（2026-11-01）
- `db:seed` は不足分だけ追加して既存のスキル・操作記録を保持する。デモ前に完全な初期状態へ戻すときだけ `db:seed:replant`（全件削除）を使う。（2026-11-01）
- 新規DBへの `db:prepare` は seeds も投入するため、空のDBを前提にするRSpecがCIだけで失敗する → CIは `RAILS_ENV=test` で `db:create db:schema:load` を使い、seedsのspecだけ明示的に読み込む。修正確認は既存のテストDBだけでなく新規の専用DBでも行う。（2026-11-01）
