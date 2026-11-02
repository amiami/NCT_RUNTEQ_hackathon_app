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

    it "スタッフの名前の行の下に、全部の列にまたがる区切りの線がある（セルのすき間で途切れないよう1つの行にする）" do
      rule = document.find("table.skill-map thead tr:last-child td.skill-map-head-rule")

      expect(rule[:colspan]).to eq "3"
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

  describe "できる人チェック（上部の警告と絞り込み）" do
    let(:filter_label) { "できる人が1人以下の作業だけ表示" }

    def warning
      document.find(".capable-warning")
    end

    def make_capable(operation, users)
      users.each { |user| create(:skill, user:, operation:, level: 4) }
    end

    context "できる人が1人以下の作業があるとき" do
      before do
        # 給与計算：0人、勤怠の締め：1人、入社手続き：2人
        make_capable(attendance, [ yamamoto ])
        make_capable(joining, [ yamamoto, nakamura ])
        get admin_skill_map_path
      end

      it "AC-1: 表より上に、できる人が1人以下の作業の件数を添えた警告が出る" do
        expect(warning).to have_text("できる人（1人でできる＝レベル4）が1人以下の作業が2件あります")
        expect(warning).to have_text("担当者が休んだり辞めたりすると止まる恐れがあります。研修画面で優先して教える人を決めましょう。")
        expect(response.body.index("capable-warning")).to be < response.body.index("<table")
      end

      it "AC-1: 警告は表のカードの中ではなく、その上の別のカードとして出る" do
        expect(document).to have_css(".capable-warning.card")
        expect(document).to have_no_css("section.card .capable-warning")
      end

      it "AC-1: 警告に絞り込みのボタンがあり、押すと skill-map コントローラで切り替える（最初は押していない状態）" do
        button = warning.find("button", text: filter_label)

        expect(button[:type]).to eq "button"
        expect(button["aria-pressed"]).to eq "false"
        expect(button["data-action"]).to eq "skill-map#toggleFewCapable"
        expect(document).to have_css("[data-controller='skill-map'] .capable-warning")
      end

      it "AC-3: 作業の行に、できる人が1人以下か（絞り込みで残すか）の印が付く" do
        expect(row(payroll)["data-few-capable"]).to eq "true"
        expect(row(attendance)["data-few-capable"]).to eq "true"
        expect(row(joining)["data-few-capable"]).to eq "false"
      end

      it "AC-3: できる人が1人以下の作業がない分類は、見出しごと隠す印が付く" do
        expect(document.find("tbody", text: "勤怠・給与")["data-few-capable"]).to eq "true"
        expect(document.find("tbody", text: "入退社")["data-few-capable"]).to eq "false"
      end
    end

    it "AC-2: 全作業でできる人が2人以上のときは、警告もボタンも出ない" do
      [ payroll, attendance, joining ].each { |operation| make_capable(operation, [ yamamoto, nakamura ]) }

      get admin_skill_map_path

      expect(document).to have_no_css(".capable-warning")
      expect(document).to have_no_button(filter_label)
    end

    it "AC-4: レベル4の◇・▼の人も、できる人に数える" do
      make_capable(payroll, [ yamamoto, nakamura ])
      make_capable(attendance, [ yamamoto, nakamura ])
      create(:skill, user: yamamoto, operation: joining, level: 4, admin_assessment: :backup_trainer)
      create(:skill, user: nakamura, operation: joining, level: 4, admin_assessment: :needs_training)

      get admin_skill_map_path

      expect(document).to have_no_css(".capable-warning")
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

  describe "マスの詳細" do
    it "表のカードの上（カードの外）に、詳細を入れる空の枠（skill_detail）がある" do
      get admin_skill_map_path

      expect(document).to have_css("turbo-frame#skill_detail + section.card .skill-map-scroll")
      expect(document.find("turbo-frame#skill_detail", visible: :all).text).to be_blank
    end

    it "詳細が入ると、詳細が見える位置まで自動でスクロールする（Turbo Frame の autoscroll。見えていればスクロールしない）" do
      get admin_skill_map_path

      expect(document).to have_css("turbo-frame#skill_detail[autoscroll][data-autoscroll-block='nearest']", visible: :all)
    end

    it "マスを押すと、そのマスの詳細が skill_detail の枠に入る（マスが詳細へのリンクになっている）" do
      skill = create(:skill, user: yamamoto, operation: payroll)

      get admin_skill_map_path

      link = cell(skill).find("a.skill-map-cell")
      expect(link[:href]).to eq admin_skill_path(skill)
      expect(link["data-turbo-frame"]).to eq "skill_detail"
    end

    it "マスを押すと、そのマスに選択中の印が付く（Stimulus の skill-map コントローラで付け替える）" do
      skill = create(:skill, user: yamamoto, operation: payroll)

      get admin_skill_map_path

      expect(document).to have_css("[data-controller='skill-map'] table.skill-map")
      link = cell(skill).find("a.skill-map-cell")
      expect(link["data-action"]).to eq "skill-map#select"
      expect(link["data-skill-map-target"]).to eq "cell"
      # 開いた直後は、どのマスも選ばれていない
      expect(document).to have_no_css("a.skill-map-cell[aria-current]")
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
