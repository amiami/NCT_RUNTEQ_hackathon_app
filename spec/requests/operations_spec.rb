require "rails_helper"

RSpec.describe "作業ツリーとマニュアル" do
  let!(:manager) { create(:user, :admin) }
  let!(:staff) { create(:user) }

  def document
    Capybara.string(response.body)
  end

  def switch_to(user)
    patch operator_path, params: { user_id: user.id }
  end

  shared_examples "作業を選んでマニュアルを読む" do
    let!(:earlier_category) { create(:category, name: "入社", sort_order: 1) }
    let!(:external_operation) do
      create(:operation, category: create(:category, name: "給与", sort_order: 2),
        name: "給与計算", season_note: "毎月25日", sort_order: 1)
    end
    let!(:first_operation) { create(:operation, category: earlier_category, name: "入社手続き", sort_order: 1) }
    let!(:second_operation) { create(:operation, category: earlier_category, name: "備品の準備", sort_order: 2) }
    let!(:internal_manual) { create(:manual, operation: first_operation, body: "  必要書類を確認する\n\n台帳へ登録する  ") }
    let!(:external_manual) do
      create(:manual, :external, operation: external_operation, version: 3, url: "https://example.com/payroll")
    end

    before do
      create(:manual_revision, manual: external_manual, user: manager, version: 2, created_at: Time.utc(2026, 10, 21, 0, 0))
      create(:manual_revision, manual: external_manual, user: manager, version: 3, created_at: Time.utc(2026, 10, 19, 15, 30))
    end

    it "分類と作業の表示順に並び、最初の作業のマニュアルを表示する" do
      get public_send(page_path)

      expect(response).to have_http_status(:ok)
      links = document.all("main a").select { |link| link[:href].to_s.include?("operation_id=") }
      expect(links.map { |link| URI.decode_www_form(URI.parse(link[:href]).query).to_h.fetch("operation_id") })
        .to eq([ first_operation.id, second_operation.id, external_operation.id ].map(&:to_s))
      expect(document).to have_css("main ol li", exact_text: "必要書類を確認する")
      expect(document).to have_css("main ol li", exact_text: "台帳へ登録する")
      expect(document).to have_css("main ol li", count: 2)
    end

    it "分類見出しの横に、その分類に登録されたマニュアルの種類を表示する" do
      get public_send(page_path)

      internal_heading = document.find("section[aria-labelledby='operation-category-#{earlier_category.id}'] .operation-category-heading")
      external_heading = document.find("section[aria-labelledby='operation-category-#{external_operation.category_id}'] .operation-category-heading")
      expect(internal_heading).to have_css("h2", exact_text: "入社")
      expect(internal_heading).to have_css(".operation-category-kind", exact_text: "アプリ内")
      expect(external_heading).to have_css("h2", exact_text: "給与")
      expect(external_heading).to have_css(".operation-category-kind", exact_text: "外部サイト")
    end

    it "分類に両方の種類があれば併記し、DBの種類を変えると表示も変わる" do
      second_manual = create(:manual, :external, operation: second_operation)

      get public_send(page_path)

      heading_selector = "section[aria-labelledby='operation-category-#{earlier_category.id}'] .operation-category-heading"
      expect(document.find(heading_selector)).to have_css(".operation-category-kind", exact_text: "アプリ内・外部サイト")

      second_manual.update!(kind: :internal, body: "備品を準備する")
      get public_send(page_path)

      expect(document.find(heading_selector)).to have_css(".operation-category-kind", exact_text: "アプリ内")
    end

    it "マニュアル未登録だけの分類や作業がない分類には種類バッジを出さない" do
      unregistered_category = create(:category, name: "未登録の分類")
      create(:operation, category: unregistered_category)
      empty_category = create(:category, name: "作業のない分類")

      get public_send(page_path)

      [ unregistered_category, empty_category ].each do |category|
        heading = document.find("section[aria-labelledby='operation-category-#{category.id}'] .operation-category-heading")
        expect(heading).to have_css("h2", exact_text: category.name)
        expect(heading).to have_no_css(".operation-category-kind")
      end
    end

    it "ツリーのリンクで選んだ作業に切り替わり、外部サイトを別タブで開ける" do
      get public_send(page_path)
      link = document.find("main a[href*='operation_id=#{external_operation.id}']")
      get link[:href]

      expect(response).to have_http_status(:ok)
      expect(document).to have_css("main h2", text: "給与計算")
      expect(document).to have_link("https://example.com/payroll", href: external_manual.url)
      expect(document).to have_css("main a[href='#{external_manual.url}'][target='_blank']", text: "サイトを開く")
      expect(document.find("main a[href*='operation_id=#{external_operation.id}']")[:"aria-current"]).to eq("page")
      document.all("main a[href='#{external_manual.url}']").each do |site_link|
        expect(site_link[:rel].split).to include("noopener", "noreferrer")
      end
      expect(document).to have_no_css("main ol li", text: "必要書類を確認する")
    end

    [ "[○○のURL]", "javascript:alert('手順')" ].each do |invalid_url|
      it "外部サイトのURLが#{invalid_url}なら文字で表示し、サイトを開くボタンを押せない" do
        external_manual.update!(url: invalid_url)

        get public_send(page_path), params: { operation_id: external_operation.id }

        expect(response).to have_http_status(:ok)
        expect(document).to have_css("main", text: invalid_url)
        expect(document).to have_button("サイトを開く", disabled: true)
        expect(document.all("main a").map { |link| link[:href] }).not_to include(invalid_url)
        expect(document).to have_no_css("main a[href^='javascript:']")
      end
    end

    it "種類・版・日本時間の最終改定日・時期の目安を表示する" do
      get public_send(page_path), params: { operation_id: external_operation.id }

      manual_panel = document.find("article[aria-labelledby='operation-title']")
      expect(manual_panel).to have_css("span", exact_text: "外部サイト")
      expect(manual_panel).to have_css("span", exact_text: "第3版")
      expect(manual_panel).to have_css("span", exact_text: "最終改定：2026/10/20")
      expect(manual_panel).to have_no_text("10/21")
      expect(manual_panel).to have_css("span", exact_text: "時期：毎月25日")
    end

    it "改定されていないアプリ内マニュアルは改定なしと表示する" do
      get public_send(page_path), params: { operation_id: first_operation.id }

      expect(document).to have_css("main", text: "アプリ内")
      expect(document).to have_css("main", text: "第1版")
      expect(document).to have_css("main", text: "改定なし")
    end

    it "存在しない作業を明示したときは404を返す" do
      get public_send(page_path), params: { operation_id: Operation.maximum(:id) + 1 }

      expect(response).to have_http_status(:not_found)
    end

    it "作業IDに数値以外の値を明示したときは404を返す" do
      get public_send(page_path), params: { operation_id: "unknown" }

      expect(response).to have_http_status(:not_found)
    end

    it "手順のHTMLを実行せず、文字として表示する" do
      internal_manual.update!(body: "<script>alert('手順')</script>\n次の手順")

      get public_send(page_path), params: { operation_id: first_operation.id }

      expect(document).to have_css("main ol li", exact_text: "<script>alert('手順')</script>")
      expect(document).to have_no_css("main script")
    end

    it "マニュアル未登録の作業でもエラーにせず案内を表示する" do
      get public_send(page_path), params: { operation_id: second_operation.id }

      expect(response).to have_http_status(:ok)
      expect(document).to have_css("main h2", text: "備品の準備")
      expect(document).to have_css("main", text: "マニュアル")
      expect(document).to have_css("main", text: "登録")
    end
  end

  [ :admin_operations_path, :staff_operations_path, :root_path ].each do |path|
    context "#{path} の表示" do
      let(:page_path) { path }

      before { switch_to(staff) unless path == :admin_operations_path }

      it_behaves_like "作業を選んでマニュアルを読む"
    end

    context "#{path} に作業がないとき" do
      it "200で空の状態を表示する" do
        get public_send(path)

        expect(response).to have_http_status(:ok)
        expect(document).to have_css("main", text: "作業")
        expect(document).to have_no_css("main a[href*='operation_id=']")
      end
    end
  end

  describe "管理者の人数と改定バッジ" do
    let!(:category) { create(:category) }
    let!(:operation) { create(:operation, category: category) }
    let!(:manual) { create(:manual, operation: operation, version: 2) }

    before { create(:manual_revision, manual: manual, user: manager, version: 2, created_at: Time.zone.local(2026, 10, 20, 12)) }

    it "できる人が0人ならツリーと作業の詳細に警告を表示し、改定バッジより優先する" do
      get admin_operations_path, params: { operation_id: operation.id }

      link = document.find("main a[href*='operation_id=#{operation.id}']")
      expect(link).to have_text("できる人0人")
      expect(link).to have_no_text("改定 10/20")
      expect(document.find("article[aria-labelledby='operation-title']")).to have_text("できる人0人")
    end

    it "レベル3を数えず、レベル4の▼もできる人1人として表示する" do
      create(:skill, operation: operation, user: staff, level: 4, admin_assessment: :needs_training)
      create(:skill, operation: operation, level: 3, admin_assessment: :can_train)

      get admin_operations_path

      expect(document.find("main a[href*='operation_id=#{operation.id}']")).to have_text("できる人1人")
      expect(document).to have_no_text("できる人2人")
    end

    it "レベル4の◇も数え、できる人が2人なら警告を出さず改定バッジを表示する" do
      create(:skill, operation: operation, user: staff, level: 4, admin_assessment: :backup_trainer)
      create(:skill, operation: operation, level: 4)

      get admin_operations_path

      link = document.find("main a[href*='operation_id=#{operation.id}']")
      expect(link).to have_text("改定 10/20")
      expect(document).to have_no_text("できる人")
    end
  end

  [ :staff_operations_path, :root_path ].each do |path|
    describe "#{path} の本人のレベルと表示の制限" do
      let!(:operations) { create_list(:operation, 5) }

      before do
        operations.each_with_index do |operation, level|
          create(:manual, operation: operation)
          create(:skill, operation: operation, user: staff, level: level,
            admin_assessment: Skill.admin_assessments.keys[level % 4])
        end
        switch_to(staff)
      end

      it "ツリーの各作業に本人のレベル0〜4を表示し、別の人に切り替えると本人の表示に変わる" do
        other_staff = create(:user)
        operations.each { |operation| create(:skill, operation: operation, user: other_staff, level: 1) }

        get public_send(path)

        operations.each_with_index do |operation, level|
          expect(document.find("main a[href*='operation_id=#{operation.id}']")).to have_text("レベル#{level}")
        end

        switch_to(other_staff)
        get public_send(path)

        operations.each do |operation|
          expect(document.find("main a[href*='operation_id=#{operation.id}']")).to have_text("レベル1")
        end
      end

      it "管理者の見立てを記号・属性・JSONを含めてHTMLへ出さない" do
        get public_send(path)

        expect(response.body).not_to include("管理者の見立て", "▲", "▼", "▽", "◇",
          "admin_assessment", "can_train", "needs_training", "training_done", "backup_trainer")
      end

      it "スキルが未作成の作業はレベル0と表示し、閲覧でスキルを作成しない" do
        operation = create(:operation)
        create(:manual, operation: operation)

        expect { get public_send(path), params: { operation_id: operation.id } }.not_to change(Skill, :count)

        expect(document.find("main a[href*='operation_id=#{operation.id}']")).to have_text("レベル0")
      end

      it "管理者としてスタッフ画面を開いたときは本人のレベルを捏造しない" do
        patch operator_path, params: { user_id: nil }
        get public_send(path)

        operations.each do |operation|
          expect(document.find("main a[href*='operation_id=#{operation.id}']")).to have_no_text(/レベル[0-4]/)
        end
      end
    end
  end
end
