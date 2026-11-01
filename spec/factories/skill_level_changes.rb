FactoryBot.define do
  factory :skill_level_change do
    skill
    changed_by { skill.user }
    from_level { 0 }
    to_level { 1 }
    reason { :confirmed }
  end
end
