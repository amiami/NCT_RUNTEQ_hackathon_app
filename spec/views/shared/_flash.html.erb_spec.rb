require "rails_helper"

RSpec.describe "shared/_flash" do
  it "通知がない場合も差し替え先だけを残す" do
    render partial: "shared/flash"

    document = Capybara.string(rendered)
    expect(document).to have_css("#flash-messages", visible: :all)
    expect(document).to have_no_css("[role=status], [role=alert]", visible: :all)
  end

  it "成功通知とエラーを役割付きで表示し、HTMLをエスケープする" do
    flash[:notice] = "保存しました"
    flash.now[:alert] = "<script>alert('test')</script>"

    render partial: "shared/flash"

    document = Capybara.string(rendered)
    expect(document).to have_css('[role="status"]', text: "保存しました")
    expect(document).to have_css('[role="alert"]', text: "<script>alert('test')</script>")
    expect(document).to have_no_css("script", visible: :all)
  end

  it "複数のメッセージを表示し、表示用でないキーは含めない" do
    flash[:notice] = [ "保存しました", "更新しました" ]
    flash[:internal] = "内部データ"

    render partial: "shared/flash"

    expect(Capybara.string(rendered)).to have_css('[role="status"]', count: 2)
    expect(rendered).not_to include("内部データ")
  end
end
