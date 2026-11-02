require "rails_helper"

RSpec.describe "操作する人の切り替え" do
  let!(:manager) { create(:user, :admin, name: "管理者") }
  let!(:yamamoto) { create(:user, name: "山本 直子", sort_order: 1) }
  let!(:nakamura) { create(:user, name: "中村 健太", sort_order: 2) }

  let(:admin_paths) do
    [ admin_operations_path, admin_skill_map_path, admin_trainings_path, admin_manual_revisions_path ]
  end

  def header_of(response)
    Capybara.string(response.body).find("header")
  end

  def switch_to(user)
    patch operator_path, params: { user_id: user&.id }
  end

  describe "AC-2: 何も選んでいないとき" do
    it "部長として管理者の画面を開ける" do
      admin_paths.each do |path|
        get path

        expect(response).to have_http_status(:ok)
      end
    end

    it "ヘッダーで「管理者（部長）」が選ばれている" do
      get admin_operations_path

      expect(header_of(response)).to have_css(".role-link-active", exact_text: "管理者（部長）")
      expect(header_of(response)).to have_no_css(".role-link-active", text: "スタッフ")
    end
  end

  describe "AC-1: スタッフを選んだとき" do
    before { switch_to(nakamura) }

    it "スタッフの画面に移る" do
      expect(response).to redirect_to(staff_operations_path)
    end

    it "ほかの画面に移っても、選んだ人のまま" do
      [ staff_operations_path, staff_skills_path, staff_manual_revisions_path ].each do |path|
        get path

        expect(response).to have_http_status(:ok)
        expect(header_of(response)).to have_select("操作する人", selected: "中村 健太")
        expect(header_of(response)).to have_css(".role-link-active", exact_text: "スタッフ")
      end
    end

    it "選べるのはスキルを持つ人（管理者以外）だけ" do
      get staff_operations_path

      expect(header_of(response)).to have_select("操作する人", options: [ "山本 直子", "中村 健太" ])
    end

    it "別のスタッフに選び直せる" do
      switch_to(yamamoto)
      get staff_skills_path

      expect(header_of(response)).to have_select("操作する人", selected: "山本 直子")
    end

    it "「管理者（部長）」を選ぶと部長に戻り、管理者の画面を開ける" do
      switch_to(nil)

      expect(response).to redirect_to(admin_operations_path)
      get admin_skill_map_path
      expect(response).to have_http_status(:ok)
      expect(header_of(response)).to have_css(".role-link-active", exact_text: "管理者（部長）")
    end
  end

  describe "AC-3: スタッフのとき" do
    before { switch_to(yamamoto) }

    it "管理者の画面の URL を開くと、スタッフの画面に戻される" do
      admin_paths.each do |path|
        get path

        expect(response).to redirect_to(staff_operations_path)
      end
    end

    it "戻された画面で、理由が分かる" do
      get admin_operations_path
      follow_redirect!

      expect(Capybara.string(response.body)).to have_css('[role="alert"]', text: "管理者の画面は、管理者（部長）に切り替えると開けます")
    end

    it "管理者の見立てをHTMLに含めない" do
      get staff_operations_path

      [ "▲", "▼", "▽", "◇", "管理者の見立て", "can_train", "needs_training", "training_done", "backup_trainer" ].each do |value|
        expect(response.body).not_to include(value)
      end
    end
  end

  describe "選べない人を指定したとき" do
    it "管理者のIDでは切り替わらない（スタッフのまま）" do
      switch_to(nakamura)
      switch_to(manager)

      expect(response).to redirect_to(staff_operations_path)
      get staff_skills_path
      expect(header_of(response)).to have_select("操作する人", selected: "中村 健太")
    end

    it "存在しないIDでは切り替わらない（部長のまま）" do
      patch operator_path, params: { user_id: 0 }

      expect(response).to redirect_to(admin_operations_path)
      get admin_operations_path
      expect(response).to have_http_status(:ok)
    end

    it "切り替えられなかったときは、理由を画面に出す" do
      patch operator_path, params: { user_id: 0 }
      follow_redirect!

      expect(Capybara.string(response.body)).to have_css('[role="alert"]', text: "選べない人です")
    end
  end

  describe "選んだ人がいなくなったとき" do
    it "部長に戻る" do
      switch_to(nakamura)
      nakamura.destroy!

      get admin_operations_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "ユーザーが一人もいないとき" do
    before { User.delete_all }

    it "部長として扱われ、管理者の画面を開ける" do
      get admin_operations_path

      expect(response).to have_http_status(:ok)
    end
  end
end
