# == Schema Information
#
# Table name: accounts
#
#  id                        :integer          not null, primary key
#  active_chat_limit_enabled :boolean          default(FALSE), not null
#  active_chat_limit_value   :integer          default(7)
#  auto_resolve_duration     :integer
#  custom_attributes         :jsonb
#  domain                    :string(100)
#  feature_flags             :bigint           default(0), not null
#  feature_flags_ext_1       :bigint           default(0), not null
#  internal_attributes       :jsonb            not null
#  limits                    :jsonb
#  locale                    :integer          default("en")
#  name                      :string           not null
#  queue_enabled             :boolean          default(FALSE), not null
#  queue_message             :text
#  settings                  :jsonb
#  status                    :integer          default("active")
#  support_email             :string(100)
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
# Indexes
#
#  index_accounts_on_status  (status)
#

class Account < ApplicationRecord
  # used for multi-flag bitset columns
  include FlagShihTzu
  include Reportable
  include Featurable
  include CacheKeys
  include CaptainFeaturable
  include AccountEmailRateLimitable
  include AccountSettingsSchema
  include AccountSettingsAccessors
  include AccountAssociations
  include AccountChannelAssociations
  include AccountWorkspaceAssociations

  DEFAULT_QUERY_SETTING = {
    flag_query_mode: :bit_operator,
    check_for_column: false
  }.freeze
  SUSPENSION_CATEGORIES = %w[spam non_payment other].freeze

  attr_accessor :suspension_category, :suspension_reason

  validates :name, presence: true
  validates :active_chat_limit_value, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  # `domain` is the inbound email domain used to construct reply addresses
  # (see `inbound_email_domain`). Do not repurpose it for a website or any
  # non-mail-related domain.
  validates :domain, length: { maximum: 100 }
  validates_with JsonSchemaValidator,
                 schema: SETTINGS_PARAMS_SCHEMA,
                 attribute_resolver: ->(record) { record.settings }
  validate :validate_reporting_timezone
  validate :validate_support_email_format, if: :will_save_change_to_support_email?

  before_validation :validate_limit_keys
  after_update :resume_delayed_automations, if: -> { saved_change_to_feature_delayed_automations? && feature_delayed_automations? }
  after_destroy :remove_account_sequences
  after_commit :process_queue_when_limit_changed, if: :active_chat_limit_settings_changed?

  include AccountCaptainAutoResolve

  enum :locale, LANGUAGES_CONFIG.map { |key, val| [val[:iso_639_1_code], key] }.to_h, prefix: true
  enum :status, { active: 0, suspended: 1 }

  scope :with_auto_resolve, -> { where("(settings ->> 'auto_resolve_after')::int IS NOT NULL") }
  scope :with_auto_resolve_pending, -> { where("(settings ->> 'auto_resolve_pending_after')::int IS NOT NULL") }

  after_create_commit :notify_creation
  after_update_commit :clear_unread_conversation_counts_cache, if: :saved_change_to_feature_conversation_unread_counts?

  def agents
    users.where(account_users: { role: :agent })
  end

  def administrators
    users.where(account_users: { role: :administrator })
  end

  def all_conversation_tags
    # returns array of tags
    conversation_ids = conversations.pluck(:id)
    ActsAsTaggableOn::Tagging.includes(:tag)
                             .where(context: 'labels',
                                    taggable_type: 'Conversation',
                                    taggable_id: conversation_ids)
                             .map { |tagging| tagging.tag.name }
  end

  def webhook_data
    {
      id: id,
      name: name
    }
  end

  def suspension_history
    internal_attributes['suspensions'] || []
  end

  def usage_limits
    {
      agents: ChatwootApp.max_limit.to_i,
      inboxes: ChatwootApp.max_limit.to_i
    }
  end

  def api_and_webhooks_enabled?
    true
  end

  def locale_english_name
    # the locale can also be something like pt_BR, en_US, fr_FR, etc.
    # the format is `<locale_code>_<country_code>`
    # we need to extract the language code from the locale
    account_locale = locale&.split('_')&.first
    ISO_639.find(account_locale)&.english_name&.downcase || 'english'
  end

  def active_chat_limit
    active_chat_limit_value
  end

  def active_chat_limit_settings_changed?
    saved_change_to_active_chat_limit_enabled? || saved_change_to_active_chat_limit_value?
  end

  def process_queue_when_limit_changed
    return unless queue_enabled?

    ChatQueue::ProcessQueueJob.perform_later(id)
  end

  def onboarding_step
    step = custom_attributes['onboarding_step']
    return nil if step.blank?

    enrichment_key = format(Redis::Alfred::ACCOUNT_ONBOARDING_ENRICHMENT, account_id: id)
    Redis::Alfred.exists?(enrichment_key) ? 'enrichment' : step
  end

  def reset_cache_keys
    super
    clear_unread_conversation_counts_cache
  end

  private

  def notify_creation
    Rails.configuration.dispatcher.dispatch(ACCOUNT_CREATED, Time.zone.now, account: self)
  end

  def clear_unread_conversation_counts_cache
    ::Conversations::UnreadCounts::Store.clear_account!(id)
  end

  def resume_delayed_automations
    AutomationRulePendingExecution.reschedule_paused(self)
  end

  trigger.after(:insert).for_each(:row) do
    "execute format('create sequence IF NOT EXISTS conv_dpid_seq_%s', NEW.id);"
  end

  trigger.name('camp_dpid_before_insert').after(:insert).for_each(:row) do
    "execute format('create sequence IF NOT EXISTS camp_dpid_seq_%s', NEW.id);"
  end

  def validate_limit_keys
    # method overridden in enterprise module
  end

  def remove_account_sequences
    ActiveRecord::Base.connection.exec_query("drop sequence IF EXISTS camp_dpid_seq_#{id}")
    ActiveRecord::Base.connection.exec_query("drop sequence IF EXISTS conv_dpid_seq_#{id}")
  end
end

Account.prepend_mod_with('Account')
Account.prepend_mod_with('Account::PlanUsageAndLimits')
Account.include_mod_with('AccountBillingIdentity')
Account.include_mod_with('Concerns::Account')
Account.include_mod_with('Audit::Account')
