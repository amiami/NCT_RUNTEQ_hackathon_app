require "rails_helper"

RSpec.describe AdminAssessmentsHelper do
  def mark_for(level, assessment)
    Capybara.string(helper.assessment_mark(build(:skill, level:, admin_assessment: assessment)).to_s)
  end

  describe "#assessment_mark" do
    it "見立てごとのアイコン（SVG）を出し、名前をマウスを乗せたときの説明と読み上げ用の名前にする（記号の文字は出さない）" do
      mark = mark_for(3, :can_train).find("span.assessment-mark.assessment-mark-can_train")

      expect(mark[:title]).to eq "指導できる"
      expect(mark[:role]).to eq "img"
      expect(mark["aria-label"]).to eq "指導できる"
      expect(mark).to have_css("svg[aria-hidden='true'] path", visible: :all)
      expect(mark.native.to_html).not_to include("▲")
    end

    it "4つの見立てそれぞれに、別の形のアイコンがある" do
      shapes = { 3 => %i[can_train needs_training training_done], 4 => %i[backup_trainer] }.flat_map do |level, assessments|
        assessments.map { |assessment| mark_for(level, assessment).find("path", visible: :all)[:d] }
      end

      expect(shapes.uniq.size).to eq 4
    end

    it "今のレベルで意味のない見立て（4▲など）と、見立てがないときは何も出さない" do
      expect(helper.assessment_mark(build(:skill, level: 4, admin_assessment: :can_train))).to be_nil
      expect(helper.assessment_mark(build(:skill, level: 3, admin_assessment: nil))).to be_nil
    end
  end

  it "AC-1: 見立ての名前と記号は ja.yml の admin_assessments だけに書く（admin_assessment_marks はない）" do
    expect(I18n.exists?("admin_assessment_marks")).to be false
    expect(I18n.t("admin_assessments").keys).to eq Skill.admin_assessments.keys.map(&:to_sym)
  end
end
