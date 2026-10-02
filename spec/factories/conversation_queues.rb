FactoryBot.define do
  factory :conversation_queue do
    association :conversation
    account { conversation.account }
    queued_at { Time.current }
    position { 1 }
  end
end
