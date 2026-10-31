FactoryBot.define do
  factory :training do
    operation
    trainer { association :user }
    trainee { association :user }
  end
end
