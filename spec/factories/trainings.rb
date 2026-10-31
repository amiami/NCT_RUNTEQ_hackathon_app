FactoryBot.define do
  factory :training do
    operation
    # 作成時の条件を満たすよう、その作業のスキルも作る（教える人はレベル4、教わる人はレベル0）
    trainer { FactoryBot.create(:skill, operation:, level: 4).user }
    trainee { FactoryBot.create(:skill, operation:, level: 0).user }
  end
end
