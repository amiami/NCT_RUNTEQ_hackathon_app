# テスト

- `build(:training)` は作成時の条件を満たすスキル（教える人はレベル4、教わる人はレベル0）をその作業に自動で作る → `operation: nil` や別の作業を渡すときは、`trainer:`・`trainee:` やスキルを自分で用意する。（2026-10-31）
- `validates :trainee_id, uniqueness:` のエラーは `trainee` ではなく `trainee_id` に付く → `ja.yml` の翻訳キー（`errors.models.training.attributes.trainee_id.taken`）と属性名も `trainee_id` で書く。（2026-10-31）
- `bin/rails runner` で動きを確かめるときに `create!` すると開発用 DB にデータが残る → `ActiveRecord::Base.transaction do … raise ActiveRecord::Rollback end` の中で実行する（`raise` をトランザクションの外に書かない）。（2026-10-31）
- seeds の過去の完了済み研修は、現在のレベルでは依頼時の候補条件（作成時バリデーション）を満たさない → 固定の完了履歴だけ検証を省いて投入し、相手・状態・日付は `spec/seeds/seeds_spec.rb` で検証する。通常の研修作成には使わない。（2026-11-01）
- `db:seed` は不足分だけ追加して既存のスキル・操作記録を保持する。デモ前に完全な初期状態へ戻すときだけ `db:seed:replant`（全件削除）を使う。（2026-11-01）
