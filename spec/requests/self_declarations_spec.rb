require "rails_helper"

RSpec.describe "自己申告（レベル3・4）" do
  let(:staff) { create(:user, name: "吉田 あかり") }
  let(:manual) { create(:manual) }
  let!(:skill) { create(:skill, user: staff, operation: manual.operation, level: 1, confirmed_version: manual.version) }

  let(:declare3_label) { "先輩のもとでできる（レベル3）" }
  let(:declare4_label) { "最後まで1人でできる（レベル4）" }

  # 操作する人を選んでいないときは管理者として操作する（管理者のときのテストで使う）
  before { create(:user, :admin) }

  def document
    Capybara.string(response.body)
  end

  def switch_to(user)
    patch operator_path, params: { user_id: user.id }
  end

  def declare(level, params = {})
    post staff_operation_self_declaration_path(manual.operation), params: { level: }.merge(params)
  end

  def open_manual
    get staff_operations_path, params: { operation_id: manual.operation_id }
  end

  describe "申告する" do
    before { switch_to(staff) }

    it "AC-1・AC-5: レベルが変わって同じ作業の画面に戻り、知らせが出る" do
      expect { declare(3) }.to change(SkillLevelChange, :count).by(1)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(staff_operations_path(operation_id: manual.operation_id))
      expect(skill.reload.level).to eq 3
      follow_redirect!
      expect(document).to have_css(".flash-message", text: "レベル3（先輩のもとでできる）を申告しました")
      expect(document).to have_css(".operation-confirmation-level", text: "先輩のもとでできる")
    end

    it "AC-2: レベル4を申告すると、知らせにレベル4の名前が出る" do
      declare(4)

      expect(skill.reload.level).to eq 4
      follow_redirect!
      expect(document).to have_css(".flash-message", text: "レベル4（作業を最後まで1人でできる）を申告しました")
    end

    it "AC-3: 申告できないレベルのときに送っても変わらず、理由が出る" do
      skill.update!(level: 0)

      expect { declare(3) }.not_to change(SkillLevelChange, :count)

      expect(response).to redirect_to(staff_operations_path(operation_id: manual.operation_id))
      expect(skill.reload.level).to eq 0
      follow_redirect!
      expect(document).to have_css(".flash-message", text: "今のレベルからは申告できません")
    end

    it "ほかの人のスキルは変わらない（送るのはレベルだけで、本人のスキルを変える）" do
      other_skill = create(:skill, operation: manual.operation, level: 1)

      declare(4, user_id: other_skill.user_id, skill_id: other_skill.id)

      expect(skill.reload.level).to eq 4
      expect(other_skill.reload.level).to eq 1
    end

    it "申告したあとの HTML にも、管理者の見立てが含まれない" do
      skill.update!(admin_assessment: :needs_training, level: 3)

      declare(4)
      follow_redirect!

      [ "▲", "▼", "▽", "◇", "管理者の見立て", "needs_training" ].each do |value|
        expect(response.body).not_to include(value)
      end
    end
  end

  describe "AC-7: 管理者のとき" do
    it "直接送っても拒否され、レベルは変わらない" do
      expect { declare(3) }.not_to change(SkillLevelChange, :count)

      expect(response).to have_http_status(:forbidden)
      expect(skill.reload.level).to eq 1
    end

    it "管理者の作業ツリーには、自己申告のボタンがない" do
      get admin_operations_path, params: { operation_id: manual.operation_id }

      expect(document).to have_no_button(declare3_label)
      expect(document).to have_no_button(declare4_label)
    end
  end

  describe "ボタンとヒント（スタッフの作業マニュアル）" do
    before { switch_to(staff) }

    {
      0 => [ false, false ],
      1 => [ true, true ],
      2 => [ true, true ],
      3 => [ false, true ],
      4 => [ true, false ]
    }.each do |level, (can_declare3, can_declare4)|
      it "AC-1〜3: レベル#{level}のとき、レベル3は#{can_declare3 ? '押せる' : '押せない'}・レベル4は#{can_declare4 ? '押せる' : '押せない'}" do
        skill.update!(level:)

        open_manual

        expect(document).to have_button(declare3_label, disabled: !can_declare3)
        expect(document).to have_button(declare4_label, disabled: !can_declare4)
      end
    end

    it "AC-3: その作業のスキルがまだない（レベル0）ときは、どちらも押せない" do
      skill.destroy!

      open_manual

      expect(document).to have_button(declare3_label, disabled: true)
      expect(document).to have_button(declare4_label, disabled: true)
    end

    it "押すと、本人の作業の申告の送り先にレベルを送る" do
      open_manual

      form = document.find_button(declare3_label).ancestor("form")
      expect(form[:action]).to eq staff_operation_self_declaration_path(manual.operation)
      expect(form).to have_field("level", with: "3", type: :hidden)
    end

    {
      0 => "マニュアルを読んで「マニュアルを確認した」を押すとレベル1になります。",
      1 => "研修を受けるとレベル2になります。自分で覚えてできるようになった場合は、下の自己申告を押してください。",
      2 => "研修済みです。先輩についてもらえばできるようになったら、下の「先輩のもとでできる」を押してください。",
      3 => "最後まで1人でできるようになったら、下の「最後まで1人でできる」を押してください。",
      4 => "最後まで1人でできる状態です。まわりの人のサポートをお願いすることがあります。"
    }.each do |level, hint|
      it "AC-8: レベル#{level}のときのヒント" do
        skill.update!(level:)

        open_manual

        expect(document).to have_css(".operation-confirmation-hint", exact_text: hint, normalize_ws: true)
      end
    end

    it "AC-8: 確認済みかどうかで変わっていた前のヒントは出ない" do
      open_manual

      expect(response.body).not_to include("この版のマニュアルは確認済みです", "レベル0の人はレベル1になります")
    end
  end
end
