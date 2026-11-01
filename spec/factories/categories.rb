FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "分類 #{n}" }
    sequence(:sort_order)
  end
end
