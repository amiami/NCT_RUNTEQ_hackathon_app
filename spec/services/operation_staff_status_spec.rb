require "rails_helper"

RSpec.describe OperationStaffStatus do
  let(:operation) { create(:manual, version: 2).operation }
  let(:manager) { create(:user, :admin) }

  def add_trainee
    trainee = create(:user)
    # 確認状況の判定でマニュアルを読む道も通るよう、確認した版を入れる
    create(:skill, user: trainee, operation: operation, confirmed_version: 1)
    create(:training, operation: operation, trainer: manager, trainee: trainee,
      status: :done, done_on: Date.new(2026, 10, 2))
    trainee
  end

  # 画面と同じく、確認状況・研修の判定と、教えた人の名前まで読む。
  # 画面ではリクエストごとに作業を読み直すので、ここでも毎回読み直した作業を渡す（前の回に読んだマニュアルを使わない）
  def query_count
    queries = []
    fresh_operation = Operation.find(operation.id)
    subscriber = ->(_name, _start, _finish, _id, payload) { queries << payload[:sql] if payload[:sql].start_with?("SELECT") && payload[:name] != "SCHEMA" }
    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        described_class.rows(fresh_operation).each do |row|
          row.skill.manual_status
          row.skill.training_status
          row.skill.latest_done_training&.trainer&.name
        end
      end
    end
    queries.size
  end

  describe ".rows" do
    it "スキルを持つ人ごとに、その人のこの作業のスキル（Skill）が入る" do
      user = create(:user, sort_order: 1)
      skill = create(:skill, user:, operation:, level: 3, confirmed_version: 1)

      row = described_class.rows(operation).first

      expect(row.user).to eq user
      expect(row.skill).to eq skill
      expect(row.skill.level).to eq 3
    end

    it "スキルがまだない人には、保存しないレベル0の Skill が入り、スキルのレコードは増えない" do
      user = create(:user)

      row = nil

      expect { row = described_class.rows(operation).first }.not_to change(Skill, :count)
      expect(row.skill).to be_new_record
      expect(row.skill).to have_attributes(user:, operation:, level: 0, confirmed_version: nil)
      expect(row.skill.manual_status).to eq :unconfirmed
      expect(row.skill.training_status).to eq :not_yet
    end

    it "研修済み（最新の完了した研修）を先に読んで、それぞれの Skill に入れておく" do
      trainee = add_trainee

      row = described_class.rows(operation).find { |r| r.user == trainee }

      expect(row.skill.latest_done_training).to eq Training.latest_done.find_by(operation:, trainee:)
      expect(row.skill.training_status).to eq :done
    end
  end

  it "AC-2: 人数が増えても、確認状況・研修の判定と教えた人を読むクエリが増えない" do
    add_trainee
    one_person_queries = query_count
    5.times { add_trainee }
    expect(query_count).to eq(one_person_queries)
    # スキル・研修済み・教えた人・スキルを持つ人・確認状況の判定で読むマニュアル（全員で1回）
    expect(one_person_queries).to eq(5)
  end
end
