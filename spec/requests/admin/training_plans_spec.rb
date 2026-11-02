require "rails_helper"

RSpec.describe "研修予定の「変更を保存」" do
  let!(:admin) { create(:user, :admin, name: "管理者", sort_order: 0) }
  let(:payroll) { create(:operation, name: "給与計算") }
  let(:yamamoto) { create(:user, name: "山本", sort_order: 1) }
  let(:yoshida) { create(:user, name: "吉田", sort_order: 2) }

  before do
    create(:skill, operation: payroll, user: yamamoto, level: 4)
    create(:skill, operation: payroll, user: yoshida, level: 1)
  end

  def save_plan(trainee: yoshida, due_on: "2026-12-01", **headers)
    patch admin_training_plan_path, params: {
      training_plan: {
        additions: [ { operation_id: payroll.id, trainer_id: yamamoto.id, trainee_id: trainee.id, due_on: } ]
      }
    }, headers:
  end

  describe "管理者として保存する（AC-1）" do
    it "予定を保存し、研修画面に戻って保存できたことを出す" do
      save_plan

      expect(response).to redirect_to(admin_trainings_path)
      expect(response).to have_http_status(:see_other)
      expect(Training.unfinished.pluck(:operation_id, :trainer_id, :trainee_id, :due_on))
        .to eq([ [ payroll.id, yamamoto.id, yoshida.id, Date.new(2026, 12, 1) ] ])

      follow_redirect!
      expect(Capybara.string(response.body)).to have_css(".flash-notice", text: "研修予定を保存しました")
    end

    it "取り消しと期限の変更も受け取る" do
      kato = create(:user, name: "加藤", sort_order: 3)
      create(:skill, operation: payroll, user: kato, level: 0)
      old = create(:training, operation: payroll, trainer: admin, trainee: yoshida)
      kept = create(:training, operation: payroll, trainer: admin, trainee: kato)

      patch admin_training_plan_path, params: {
        training_plan: { cancellations: [ old.id ], due_dates: [ { operation_id: payroll.id, due_on: "2026-12-20" } ] }
      }

      expect(response).to redirect_to(admin_trainings_path)
      expect(Training.exists?(old.id)).to be(false)
      expect(kept.reload.due_on).to eq(Date.new(2026, 12, 20))
    end
  end

  describe "保存できないとき（AC-5）" do
    it "422 を返し、理由をフラッシュの枠に出して、何も保存しない" do
      not_trainee = create(:user, name: "小林", sort_order: 3)
      create(:skill, operation: payroll, user: not_trainee, level: 2)

      expect { save_plan(trainee: not_trainee, Accept: "text/vnd.turbo-stream.html") }.not_to change(Training, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      document = Capybara.string(response.body)
      expect(document).to have_css('turbo-stream[action="replace"][target="flash-messages"]')
      expect(response.body).to include("研修予定を保存できませんでした", "給与計算（小林）：教わる人はこの作業で教わる人の条件を満たしていません")
    end
  end

  describe "スタッフとして送ったとき（AC-8）" do
    before { patch operator_path, params: { user_id: yoshida.id } }

    it "何も保存せず、スタッフの画面に戻す" do
      expect { save_plan }.not_to change(Training, :count)

      expect(response).to redirect_to(staff_operations_path)
    end
  end
end
