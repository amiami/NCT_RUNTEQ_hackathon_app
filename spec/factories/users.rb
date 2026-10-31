FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "スタッフ #{n}" }
    sequence(:sort_order)

    trait :admin do
      admin { true }
    end
  end
end
