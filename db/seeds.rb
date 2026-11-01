# 同じ初期データを各環境で再現する。既存レコードは更新せず、デモ中の操作を保持する。
# 初期状態へ戻す場合だけ db:seed:replant を使う（既存データは全件削除される）。
ApplicationRecord.transaction do
  admin = User.find_or_create_by!(name: "管理者", admin: true) { |user| user.sort_order = 0 }
  staff = [ "山本 直子", "中村 健太", "小林 由美", "加藤 翔", "吉田 あかり" ].each_with_index.map do |name, index|
    User.find_or_create_by!(name:, admin: false) { |user| user.sort_order = index + 1 }
  end
  users = [ admin, *staff ].index_by(&:name)

  # 分類内の並び順、種類、時期の目安、スタッフ順のレベル。
  categories = {
    "入退社" => [
      [ "入社手続き", :internal, nil, [ 4, 4, 4, 0, 0 ] ],
      [ "雇用契約書の作成", :internal, nil, [ 4, 4, 4, 1, 0 ] ],
      [ "退職手続き", :internal, nil, [ 4, 3, 4, 0, 0 ] ]
    ],
    "勤怠・給与" => [
      [ "勤怠の締め", :internal, nil, [ 4, 4, 3, 3, 0 ] ],
      [ "給与計算", :internal, nil, [ 4, 3, 2, 2, 1 ] ],
      [ "有給休暇の管理", :internal, nil, [ 4, 4, 4, 0, 0 ] ]
    ],
    "社会保険・税" => [
      [ "社会保険の資格取得・喪失", :external, nil, [ 4, 4, 4, 1, 0 ] ],
      [ "算定基礎届", :external, "年1回・夏（提出期限は案内ページで確認）", [ 4, 3, 3, 0, 0 ] ],
      [ "労働保険の年度更新", :external, "年1回・初夏", [ 3, 2, 3, 3, 0 ] ],
      [ "年末調整", :external, "毎年11月中に準備", [ 4, 3, 2, 2, 2 ] ]
    ],
    "採用・労務" => [
      [ "採用面接の日程調整", :internal, nil, [ 4, 4, 4, 0, 0 ] ],
      [ "健康診断の手配", :internal, "年1回", [ 4, 4, 4, 1, 0 ] ],
      [ "就業規則の管理", :internal, nil, [ 4, 3, 4, 0, 0 ] ]
    ]
  }
  revisions = {
    "有給休暇の管理" => "2026-09-20",
    "社会保険の資格取得・喪失" => "2026-10-01",
    "年末調整" => "2026-10-15"
  }
  unread_users = {
    "有給休暇の管理" => [ "小林 由美" ],
    "社会保険の資格取得・喪失" => [ "中村 健太", "小林 由美", "加藤 翔" ],
    "年末調整" => [ "中村 健太", "小林 由美", "加藤 翔", "吉田 あかり" ]
  }
  assessments = {
    [ "勤怠の締め", "小林 由美" ] => [ :can_train, admin, "2026-10-20" ],
    [ "勤怠の締め", "中村 健太" ] => [ :backup_trainer, admin, "2026-10-20" ],
    [ "年末調整", "中村 健太" ] => [ :needs_training, admin, "2026-10-20" ],
    [ "算定基礎届", "中村 健太" ] => [ :training_done, staff.first, "2026-06-20" ]
  }
  operations = {}

  categories.each_with_index do |(category_name, rows), category_index|
    category = Category.find_or_create_by!(name: category_name) { |record| record.sort_order = category_index + 1 }
    rows.each_with_index do |(name, kind, season_note, levels), index|
      operation = Operation.find_or_create_by!(category:, name:) do |record|
        record.sort_order = index + 1
        record.season_note = season_note
      end
      operations[name] = operation
      manual = Manual.find_or_create_by!(operation:) do |record|
        record.kind = kind
        record.body = "（サンプル）" if kind == :internal
        record.url = "[#{name}のURL]" if kind == :external
        record.version = revisions.key?(name) ? 2 : 1
      end
      if revisions.key?(name)
        ManualRevision.find_or_create_by!(manual:, version: 2) do |record|
          record.user = admin
          record.memo = "（サンプル）"
          record.body_before = record.body_after = "（サンプル）" if kind == :internal
          record.created_at = record.updated_at = Time.zone.parse(revisions.fetch(name))
        end
      end
      # スキルを持つ人の判定は共通スコープを使う。レベルは新規作成時だけ設定する。
      User.skill_holders.where(id: staff.map(&:id)).order(:sort_order).each do |user|
        Skill.find_or_create_by!(user:, operation:) do |record|
          record.level = levels.fetch(staff.index(user))
          unless record.level.zero?
            record.confirmed_version = unread_users.fetch(name, []).include?(user.name) ? 1 : manual.version
          end
          assessment = assessments[[ name, user.name ]]
          if assessment
            record.admin_assessment, record.admin_assessed_by, assessed_on = assessment
            record.admin_assessed_at = Time.zone.parse(assessed_on)
          end
        end
      end
    end
  end

  completed_trainings = [
    [ "給与計算", "山本 直子", "小林 由美", "2026-06-25" ],
    [ "給与計算", "山本 直子", "加藤 翔", "2026-07-24" ],
    [ "労働保険の年度更新", "管理者", "中村 健太", "2026-06-10" ],
    [ "算定基礎届", "山本 直子", "中村 健太", "2026-06-20" ],
    [ "年末調整", "山本 直子", "小林 由美", "2026-10-05" ],
    [ "年末調整", "山本 直子", "加藤 翔", "2026-10-05" ],
    [ "年末調整", "山本 直子", "吉田 あかり", "2026-10-05" ]
  ]
  completed_trainings.each do |name, trainer_name, trainee_name, done_on|
    training = Training.find_or_initialize_by(
      operation: operations.fetch(name), trainer: users.fetch(trainer_name),
      trainee: users.fetch(trainee_name), status: :done, done_on: Date.iso8601(done_on)
    )
    next unless training.new_record?

    # 過去の完了記録。現在は研修後のレベルなので、依頼時の候補条件は検証しない。
    # 通常の研修作成では使わず、固定のサンプル履歴だけを投入する。
    training.created_at = training.updated_at = Time.zone.parse(done_on)
    training.save!(validate: false)
  end
  # 初期状態には申告履歴を入れない。既存の skill_level_changes は削除しない。
end
