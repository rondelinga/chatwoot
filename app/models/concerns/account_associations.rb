module AccountAssociations
  extend ActiveSupport::Concern

  included do
    has_many :account_users, dependent: :destroy_async
    has_many :agent_bot_inboxes, dependent: :destroy_async
    has_many :agent_bots, dependent: :destroy_async
    has_many :articles, dependent: :destroy_async, class_name: '::Article'
    has_many :assignment_policies, dependent: :destroy_async
    has_many :automation_rules, dependent: :destroy_async
    has_many :automation_rule_pending_executions, dependent: :delete_all
    has_many :macros, dependent: :destroy_async
    has_many :campaigns, dependent: :destroy_async
    has_many :canned_responses, dependent: :destroy_async
    has_many :categories, dependent: :destroy_async, class_name: '::Category'
    has_many :contacts, dependent: :destroy_async
    has_many :companies, dependent: :destroy_async
    has_many :conversations, dependent: :destroy_async
    has_many :csat_survey_responses, dependent: :destroy_async
    has_many :custom_attribute_definitions, dependent: :destroy_async
    has_many :custom_filters, dependent: :destroy_async
    has_many :dashboard_apps, dependent: :destroy_async
    has_many :data_imports, dependent: :destroy_async
    has_many :hooks, dependent: :destroy_async, class_name: 'Integrations::Hook'
    has_many :inboxes, dependent: :destroy_async
    has_many :labels, dependent: :destroy_async
    has_many :users, through: :account_users

    has_one_attached :contacts_export
  end
end
