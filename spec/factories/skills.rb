FactoryBot.define do
  factory :skill do
    user
    operation
    level { 0 }
  end
end
