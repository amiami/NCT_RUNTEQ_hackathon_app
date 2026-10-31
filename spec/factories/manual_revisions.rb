FactoryBot.define do
  factory :manual_revision do
    manual
    user { association :user, :admin }
    version { 2 }
    memo { "手順を見直した" }
  end
end
