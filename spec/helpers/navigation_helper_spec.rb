require "rails_helper"

RSpec.describe NavigationHelper do
  let!(:admin) { create(:user, :admin, name: "管理者", sort_order: 0) }
  let(:yoshida) { create(:user, name: "吉田", sort_order: 1) }

  # current_user と staff_operator? はコントローラの helper_method なので、helper spec では差し替える
  def operate_as(user)
    without_partial_double_verification do
      allow(helper).to receive_messages(current_user: user, staff_operator?: user.present? && !user.admin?)
    end
  end

  def sql_count
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries.size
  end

  # 教える人が管理者の予定で、教わる人が user（作成時の条件を満たすよう、レベル0のスキルも作る）
  def learning_training(user, operation = create(:operation))
    create(:skill, operation:, user:, level: 0)
    create(:training, operation:, trainer: admin, trainee: user)
  end

  # 教える人が user の予定（教える人の条件を満たすよう、レベル4のスキルを作る）
  def teaching_training(user, operation = create(:operation))
    create(:skill, operation:, user:, level: 4)
    create(:training, operation:, trainer: user)
  end

  def unread_skill(user)
    operation = create(:operation)
    create(:manual, operation:, version: 2)
    create(:skill, operation:, user:, confirmed_version: 1)
  end

  describe "#navigation_counts" do
    context "スタッフのとき" do
      before { operate_as(yoshida) }

      it "わたしのスキルに、完了していない教える予定と教わる予定の件数を返す（AC-1）" do
        learning_training(yoshida)
        teaching_training(yoshida)
        learning_training(yoshida).update!(status: :done, done_on: Date.new(2026, 10, 1))
        create(:training) # ほかの人どうしの予定

        expect(helper.navigation_counts[:training_count]).to eq 2
      end

      it "改訂のお知らせに、自分の未確認の件数を返す（AC-2）" do
        unread_skill(yoshida)
        unread_skill(yoshida)
        unread_skill(create(:user)) # ほかの人の未確認

        expect(helper.navigation_counts[:unread_count]).to eq 2
      end

      it "スキルマップの件数は返さない" do
        expect(helper.navigation_counts).to eq(training_count: 0, unread_count: 0)
      end
    end

    context "部長のとき" do
      before { operate_as(admin) }

      it "スキルマップに、できる人が1人以下の作業の数だけを返す（AC-3）" do
        create(:operation)
        two = create(:operation)
        create_list(:skill, 2, operation: two, level: 4)
        teaching_training(yoshida) # 部長が教える人の予定があっても、スタッフ用の件数は返さない

        expect(helper.navigation_counts).to eq(skill_map_count: 2)
      end
    end

    it "ユーザーが一人もいない（current_user が nil の）ときは何も返さない" do
      operate_as(nil)

      expect(helper.navigation_counts).to eq({})
    end

    describe "AC-6: 件数を数えるときに N+1 にならない" do
      def grow(user)
        3.times do
          learning_training(user)
          teaching_training(user)
          unread_skill(user)
          create_list(:skill, 2, operation: create(:operation), level: 4)
        end
      end

      it "スタッフのとき、データが増えても問い合わせの回数が変わらない" do
        operate_as(yoshida)
        before_growth = sql_count { helper.navigation_counts }
        grow(yoshida)

        expect(sql_count { helper.navigation_counts }).to eq before_growth
      end

      it "部長のとき、データが増えても問い合わせの回数が変わらない" do
        operate_as(admin)
        before_growth = sql_count { helper.navigation_counts }
        grow(yoshida)

        expect(sql_count { helper.navigation_counts }).to eq before_growth
      end
    end
  end
end
