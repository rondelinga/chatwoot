FactoryBot.define do
  factory :queue_statistic do
    association :account
    date { Date.current }
  end
end
