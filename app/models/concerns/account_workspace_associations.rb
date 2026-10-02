module AccountWorkspaceAssociations
  extend ActiveSupport::Concern

  included do
    has_many :mentions, dependent: :destroy_async
    has_many :messages, dependent: :destroy_async
    has_many :conversation_queues, dependent: :destroy_async
    has_many :queue_statistics, dependent: :destroy_async
    has_many :notes, dependent: :destroy_async
    has_many :notification_settings, dependent: :destroy_async
    has_many :notifications, dependent: :destroy_async
    has_many :portals, dependent: :destroy_async, class_name: '::Portal'
    has_many :teams, dependent: :destroy_async
    has_many :webhooks, dependent: :destroy_async
    has_many :working_hours, dependent: :destroy_async
    has_many :routing_types, dependent: :destroy_async
  end
end
