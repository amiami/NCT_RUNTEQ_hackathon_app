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

  it "管理者には立場のスイッチだけを表示し、スタッフ名のスイッチは表示しない" do
    get admin_operations_path
    header = header_of(response)
    expect(header.find(".role-navigation").all("button").map(&:text)).to eq([ "管理者（部長）", "スタッフ" ])
    expect(header).to have_no_css(".operator-navigation")
  end

  it "スタッフ側へ切り替えるボタンは先頭のスタッフを指定する" do
    get admin_operations_path
    form = header_of(response).find_button("スタッフ").find(:xpath, "..")
    expect(form.find('input[name="user_id"]', visible: false).value).to eq(yamamoto.id.to_s)
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
        expect(header_of(response)).to have_css('button[aria-pressed="true"]', exact_text: "中村 健太")
        expect(header_of(response).find('.operator-navigation')).to have_css('button[aria-pressed="true"]', count: 1)
      end
    end

    it "選べるのはスキルを持つ人（管理者以外）だけ" do
      get staff_operations_path

      expect(header_of(response).find(".role-navigation").all("button").map(&:text)).to eq([ "管理者（部長）", "スタッフ" ])
      expect(header_of(response).find(".operator-navigation").all("button").map(&:text)).to eq([ "山本 直子", "中村 健太" ])
    end

    it "別のスタッフに選び直せる" do
      switch_to(yamamoto)
      get staff_skills_path

      expect(header_of(response)).to have_css('button[aria-pressed="true"]', exact_text: "山本 直子")
    end

    it "「管理者（部長）」を選ぶと部長に戻り、管理者の画面を開ける" do
      switch_to(nil)

      expect(response).to redirect_to(admin_operations_path)
      get admin_skill_map_path
      expect(response).to have_http_status(:ok)
      expect(header_of(response)).to have_css(".role-link-active", exact_text: "管理者（部長）")
    end
  end

  describe "スタッフ同士の切り替えでは開いている画面を保つ" do
    before { switch_to(nakamura) }

    it "各スタッフ画面の名前ボタンで、同じ画面の別のスタッフに切り替わる" do
      [ staff_operations_path, staff_skills_path, staff_manual_revisions_path ].each do |path|
        get path
        form = header_of(response).find(".operator-navigation").find_button("山本 直子").find(:xpath, "..")
        destination = form.find('input[name="return_to"]', visible: false).value
        patch operator_path, params: { user_id: yamamoto.id, return_to: destination }

        expect(response).to redirect_to(path)
        follow_redirect!
        expect(header_of(response).find(".operator-navigation")).to have_css('button[aria-pressed="true"]', exact_text: "山本 直子")
        switch_to(nakamura)
      end
    end

    it "作業マニュアルで選択していた作業も保つ" do
      operation = create(:manual).operation
      get staff_operations_path(operation_id: operation.id)
      form = header_of(response).find(".operator-navigation").find_button("山本 直子").find(:xpath, "..")
      operation_id = form.find('input[name="operation_id"]', visible: false).value
      patch operator_path, params: { user_id: yamamoto.id, return_to: staff_operations_path, operation_id: }

      expect(response).to redirect_to(staff_operations_path(operation_id: operation.id))
    end

    it "外部URLや許可していない画面には移動しない" do
      [ "https://example.com/", "//example.com/", admin_skill_map_path, "/staff/skills?user_id=0" ].each do |path|
        patch operator_path, params: { user_id: yamamoto.id, return_to: path }
        expect(response).to redirect_to(staff_operations_path)
      end
    end

    it "管理者への切り替えは管理者の作業ツリーに戻る" do
      patch operator_path, params: { user_id: "", return_to: staff_skills_path }
      expect(response).to redirect_to(admin_operations_path)
    end
  end

  it "管理者からスタッフへの切り替えは作業マニュアルを開く" do
    patch operator_path, params: { user_id: yamamoto.id, return_to: staff_skills_path }
    expect(response).to redirect_to(staff_operations_path)
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
      expect(header_of(response)).to have_css('button[aria-pressed="true"]', exact_text: "中村 健太")
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
      expect(header_of(response)).to have_button("スタッフ", disabled: true)
    end
  end
end
