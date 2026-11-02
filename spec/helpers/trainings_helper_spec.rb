require "rails_helper"

RSpec.describe TrainingsHelper do
  before { travel_to(Time.zone.local(2026, 11, 2, 10, 30)) }

  describe "#due_soon?（期限まで14日以内ならオレンジ）" do
    it "今日から14日後までは true（期限を過ぎていても true）" do
      [ Date.new(2026, 10, 30), Date.new(2026, 11, 2), Date.new(2026, 11, 16) ].each do |date|
        expect(helper.due_soon?(date)).to be(true), date.to_s
      end
    end

    it "15日後より先は false" do
      expect(helper.due_soon?(Date.new(2026, 11, 17))).to be(false)
    end

    it "期限がなければ false" do
      expect(helper.due_soon?(nil)).to be(false)
    end
  end
end
