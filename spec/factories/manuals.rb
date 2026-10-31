FactoryBot.define do
  factory :manual do
    operation
    kind { :internal }
    body { "手順1\n手順2" }

    trait :external do
      kind { :external }
      body { nil }
      url { "https://example.com/manual" }
    end
  end
end
