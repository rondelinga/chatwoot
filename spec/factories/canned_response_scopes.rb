FactoryBot.define do
  factory :canned_response_scope do
    canned_response

    trait :user_scope do
      user
    end

    trait :team_scope do
      team
    end

    trait :inbox_scope do
      inbox
    end
  end
end
