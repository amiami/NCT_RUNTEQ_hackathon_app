require "rails_helper"

RSpec.describe "共通レイアウト" do
  {
    admin_operations_path: [ "作業ツリー（マニュアル）", :admin ],
    admin_skill_map_path: [ "スキルマップ", :admin ],
    admin_trainings_path: [ "研修", :admin ],
    admin_manual_revisions_path: [ "改訂履歴", :admin ],
    staff_operations_path: [ "作業マニュアル", :staff ],
    staff_skills_path: [ "わたしのスキル", :staff ],
    staff_manual_revisions_path: [ "改訂のお知らせ", :staff ]
  }.each do |route, (title, audience)|
    context "#{title}を開いた場合" do
      before { get public_send(route) }

      it "共通ヘッダーと画面の見出しを表示する" do
        expect(response).to have_http_status(:ok)
        document = Capybara.string(response.body)

        expect(document).to have_css("header", text: I18n.t("app_name"))
        expect(document).to have_css("main h1", exact_text: "#{audience == :admin ? '管理者' : 'スタッフ'}：#{title}")
        expect(document).to have_css("details summary", text: "レベルの説明")
        expect(document).to have_css("#flash-messages", visible: :all)
        # ユーザーも作業もないので、どのタブも0件。0件のときはバッジを出さず、仮表示の99も出さない
        expect(document).to have_no_css(".notification-count")
      end

      it "同じ立場の全タブにリンクし、現在のタブだけを強調する" do
        document = Capybara.string(response.body)
        navigation = document.find('nav[aria-label="画面切り替え"]')

        expect(navigation).to have_css("a", count: audience == :admin ? 4 : 3)
        expect(navigation).to have_css('a[aria-current="page"]', count: 1, text: title)
        expect(navigation).to have_link(title, href: public_send(route))
        navigation.all("a").each do |link|
          expect(link[:href]).to start_with("/#{audience}/")
        end
      end

      if audience == :staff
        it "管理者の見立てをHTMLにも含めない" do
          [ "▲", "▼", "▽", "◇", "管理者の見立て", "can_train", "needs_training", "training_done", "backup_trainer" ].each do |value|
            expect(response.body).not_to include(value)
          end
        end
      else
        it "管理者向けの見立ての説明を含める" do
          expect(response.body).to include("▲ 研修権限", "▼ 要研修", "▽ 研修済み", "◇ 教えるのは後回し")
        end
      end
    end
  end
end
