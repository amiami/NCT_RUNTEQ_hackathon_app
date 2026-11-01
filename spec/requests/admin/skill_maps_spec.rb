require "rails_helper"

RSpec.describe "スキルマップ（管理者）" do
  # 管理者は列に入らないことを確かめるために作る
  before { create(:user, :admin, name: "管理者") }

  let!(:nakamura) { create(:user, name: "中村 健太", sort_order: 2) }
  let!(:yamamoto) { create(:user, name: "山本 直子", sort_order: 1) }

  let!(:payroll_category) { create(:category, name: "勤怠・給与", sort_order: 2) }
  let!(:joining_category) { create(:category, name: "入退社", sort_order: 1) }
  let!(:payroll) { create(:operation, category: payroll_category, name: "給与計算", sort_order: 2) }
  let!(:attendance) { create(:operation, category: payroll_category, name: "勤怠の締め", sort_order: 1) }
  let!(:joining) { create(:operation, category: joining_category, name: "入社手続き", sort_order: 1) }

  def document
    Capybara.string(response.body)
  end

  def cell(skill)
    document.find("#skill_#{skill.id}")
  end

  def row(operation)
    document.find("tr", text: operation.name)
  end

  describe "AC-1: 行が作業（分類ごと）、列がスタッフ" do
    before do
      [ payroll, attendance, joining ].each do |operation|
        [ yamamoto, nakamura ].each { |user| create(:skill, user:, operation:) }
      end
      get admin_skill_map_path
    end

    it "列の見出しがスタッフの並び順で、管理者は入らない" do
      expect(document.all("table.skill-map thead th[scope='col']").map(&:text)).to eq [ "山本 直子", "中村 健太" ]
      expect(document.find("table.skill-map thead")).to have_no_text("管理者")
    end

    it "分類の見出しの下に、その分類の作業が並び順で並ぶ" do
      headings = document.all("table.skill-map tbody th").map { |th| th.text.squish }

      expect(headings.map { |text| text[/\A\S+/] }).to eq [ "入退社", "入社手続き", "勤怠・給与", "勤怠の締め", "給与計算" ]
    end

    it "分類の見出しに作業の数が出る" do
      expect(document.find("tr.skill-map-category", text: "勤怠・給与")).to have_text("2作業")
    end
  end

  describe "AC-2: マスにレベルが出て、高いほど濃い青になる" do
    it "0〜4のレベルと、レベルごとの色のクラスが付く" do
      users = [ yamamoto, nakamura ] + create_list(:user, 3)
      skills = (0..4).map { |level| create(:skill, user: users[level], operation: joining, level:) }

      get admin_skill_map_path

      skills.each do |skill|
        # マスの中の改行・インデントを無視して比べる
        expect(cell(skill)).to have_css(".skill-level-#{skill.level}", exact_text: skill.level.to_s, normalize_ws: true)
      end
    end
  end

  describe "AC-5: できる人が1人以下の作業に「できる人○人」が出る" do
    before do
      # 給与計算：0人、勤怠の締め：1人（◇）、入社手続き：2人（うち1人は▼）
      create(:skill, user: yamamoto, operation: payroll, level: 3)
      create(:skill, user: yamamoto, operation: attendance, level: 4, admin_assessment: :backup_trainer)
      create(:skill, user: nakamura, operation: attendance, level: 3)
      create(:skill, user: yamamoto, operation: joining, level: 4)
      create(:skill, user: nakamura, operation: joining, level: 4, admin_assessment: :needs_training)
      get admin_skill_map_path
    end

    it "0人・1人の作業の行に出る（◇・▼の人も数える）" do
      expect(row(payroll)).to have_css(".capable-alert", exact_text: "できる人0人")
      expect(row(attendance)).to have_css(".capable-alert", exact_text: "できる人1人")
    end

    it "2人以上の作業の行には出ない" do
      expect(row(joining)).to have_no_css(".capable-alert")
    end

    it "分類の見出しに、できる人が1人以下の作業の件数が出る" do
      expect(document.find("tr.skill-map-category", text: "勤怠・給与")).to have_css(".capable-alert", exact_text: "できる人1人以下 2件")
    end

    it "できる人が1人以下の作業がない分類の見出しには出ない" do
      expect(document.find("tr.skill-map-category", text: "入退社")).to have_no_css(".capable-alert")
    end
  end

  describe "「未読」の印" do
    let!(:manual) { create(:manual, operation: payroll, version: 2) }

    it "AC-6: 改定後にマニュアルをまだ確認していない人のマスに出る" do
      skill = create(:skill, user: yamamoto, operation: payroll, level: 2, confirmed_version: 1)

      get admin_skill_map_path

      expect(cell(skill)).to have_css(".skill-map-unread", exact_text: "未読")
    end

    it "AC-7: 一度も確認していない人（confirmed_version が NULL）のマスには出ない" do
      skill = create(:skill, user: yamamoto, operation: payroll, level: 0, confirmed_version: nil)

      get admin_skill_map_path

      expect(cell(skill)).to have_no_css(".skill-map-unread")
    end

    it "AC-8: マウスを乗せると説明が出る" do
      skill = create(:skill, user: yamamoto, operation: payroll, level: 2, confirmed_version: 1)

      get admin_skill_map_path

      expect(cell(skill).find(".skill-map-unread")[:title]).to eq I18n.t("admin.skill_maps.cell.unread_description")
    end

    it "AC-9: マニュアルを確認する（確認した版が今の版になる）と消える" do
      skill = create(:skill, user: yamamoto, operation: payroll, level: 2, confirmed_version: 1)
      # 「マニュアルを確認した」ボタン（#49）が更新するのと同じ値にする
      skill.update!(confirmed_version: manual.version)

      get admin_skill_map_path

      expect(cell(skill)).to have_no_css(".skill-map-unread")
    end
  end

  describe "管理者の見立ての印" do
    def skill_with(level, assessment)
      create(:skill, user: yamamoto, operation: payroll, level:, admin_assessment: assessment)
    end

    describe "AC-3: 今のレベルで意味のある見立てだけ、マスに出る" do
      {
        [ 3, :can_train ] => "▲",
        [ 3, :needs_training ] => "▼",
        [ 3, :training_done ] => "▽",
        [ 4, :needs_training ] => "▼",
        [ 4, :backup_trainer ] => "◇"
      }.each do |(level, assessment), symbol|
        it "レベル#{level}・#{assessment} は #{symbol} が出る" do
          skill = skill_with(level, assessment)

          get admin_skill_map_path

          expect(cell(skill)).to have_css(".assessment-mark", exact_text: symbol)
        end
      end

      [ [ 4, :can_train ], [ 4, :training_done ], [ 3, :backup_trainer ], [ 4, nil ] ].each do |level, assessment|
        it "レベル#{level}・#{assessment || 'なし'} は、印も値も HTML に出ない" do
          skill = skill_with(level, assessment)

          get admin_skill_map_path

          expect(cell(skill)).to have_no_css(".assessment-mark")
          html = cell(skill).native.to_html
          [ "▲", "▼", "▽", "◇", *assessment&.to_s ].each { |value| expect(html).not_to include(value) }
        end
      end
    end

    describe "AC-4: マウスを乗せると説明が出る" do
      {
        [ 3, :can_train ] => "研修権限：レベル3だが、すでに教えられる",
        [ 3, :needs_training ] => "要研修：研修が必要",
        [ 3, :training_done ] => "研修済み：▼の人が研修を受け終えた",
        [ 4, :backup_trainer ] => "教えるのは後回し：1人で作業はできるが、教えるのは少し不得意"
      }.each do |(level, assessment), description|
        it "#{assessment} の説明" do
          skill = skill_with(level, assessment)

          get admin_skill_map_path

          expect(cell(skill).find(".assessment-mark")[:title]).to eq description
        end
      end
    end

    it "AC-8: 「未読」と見立ての印は、マスの中で別々の印として出る（見立ては右上に重ねて置く）" do
      create(:manual, operation: payroll, version: 2)
      skill = create(:skill, user: yamamoto, operation: payroll, level: 3, admin_assessment: :can_train, confirmed_version: 1)

      get admin_skill_map_path

      expect(cell(skill)).to have_css(".skill-map-cell > .assessment-mark", exact_text: "▲")
      expect(cell(skill)).to have_css(".skill-map-cell > .skill-map-unread", exact_text: "未読")
    end
  end

  describe "AC-10: スタッフのとき" do
    it "スタッフの画面に戻される" do
      patch operator_path, params: { user_id: yamamoto.id }

      get admin_skill_map_path

      expect(response).to redirect_to(staff_operations_path)
    end
  end
end
