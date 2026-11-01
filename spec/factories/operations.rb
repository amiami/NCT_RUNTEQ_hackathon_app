FactoryBot.define do
  factory :operation do
    category
    sequence(:name) { |n| "作業 #{n}" }
    sequence(:sort_order)
  end
end
