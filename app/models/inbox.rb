# frozen_string_literal: true

# == Schema Information
#
# Table name: inboxes
#
#  id                              :integer          not null, primary key
#  allow_messages_after_resolved   :boolean          default(TRUE)
#  auto_assignment_config          :jsonb
#  business_name                   :string
#  channel_type                    :string
#  csat_config                     :jsonb            not null
#  csat_survey_enabled             :boolean          default(FALSE)
#  email_address                   :string
#  enable_auto_assignment          :boolean          default(TRUE)
#  enable_email_collect            :boolean          default(TRUE)
#  greeting_enabled                :boolean          default(FALSE)
#  greeting_message                :string
#  lock_to_single_conversation     :boolean          default(FALSE), not null
#  name                            :string           not null
#  out_of_office_message           :string
#  public_name                     :string
#  queue_notification_enabled      :boolean          default(TRUE), not null
#  resolution_notification_enabled :boolean          default(TRUE), not null
#  sender_name_type                :integer          default("friendly"), not null
#  timezone                        :string           default("UTC")
#  working_hours_enabled           :boolean          default(FALSE)
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  account_id                      :integer          not null
#  channel_id                      :integer          not null
#  portal_id                       :bigint
#  priority_group_id               :bigint
#
# Indexes
#
#  index_inboxes_on_account_id                   (account_id)
#  index_inboxes_on_channel_id_and_channel_type  (channel_id,channel_type)
#  index_inboxes_on_portal_id                    (portal_id)
#  index_inboxes_on_priority_group_id            (priority_group_id)
#
# Foreign Keys
#
#  fk_rails_...  (portal_id => portals.id)
#  fk_rails_...  (priority_group_id => priority_groups.id)
#

class Inbox < ApplicationRecord
  include Reportable
  include Avatarable
  include OutOfOffisable
  include AccountCacheRevalidator
  include InboxAgentAvailability
  include InboxBrandedEmailLayoutable
  include InboxBotStatus
  include InboxChannelTypes
  include InboxNameSanitizer

  # Not allowing characters:
  validates :name, presence: true
  validates :account_id, presence: true
  validates :timezone, inclusion: { in: TZInfo::Timezone.all_identifiers }
  validates :out_of_office_message, length: { maximum: Limits::OUT_OF_OFFICE_MESSAGE_MAX_LENGTH }
  validates :greeting_message, length: { maximum: Limits::GREETING_MESSAGE_MAX_LENGTH }
  validates :public_name, length: { maximum: 255 }, allow_blank: true
  validate :ensure_valid_max_assignment_limit

  belongs_to :account
  belongs_to :portal, optional: true

  belongs_to :channel, polymorphic: true, dependent: :destroy

  has_many :campaigns, dependent: :destroy_async
  has_many :contact_inboxes, dependent: :destroy_async
  has_many :contacts, through: :contact_inboxes
  has_many :conversation_queues, dependent: :destroy

  has_many :inbox_members, dependent: :destroy_async
  has_many :members, through: :inbox_members, source: :user
  has_many :inbox_teams, dependent: :destroy
  has_many :teams, through: :inbox_teams
  has_many :conversations, dependent: :destroy_async
  has_many :messages, dependent: :destroy_async
  has_many :email_templates, dependent: :destroy_async

  has_one :inbox_assignment_policy, dependent: :destroy
  has_one :assignment_policy, through: :inbox_assignment_policy
  has_one :agent_bot_inbox, dependent: :destroy_async
  has_one :agent_bot, through: :agent_bot_inbox
  has_many :webhooks, dependent: :destroy_async
  has_many :hooks, dependent: :destroy_async, class_name: 'Integrations::Hook'

  enum sender_name_type: { friendly: 0, professional: 1 }

  before_destroy :capture_filtered_unread_count_user_ids, prepend: true
  after_destroy :delete_round_robin_agents

  after_create_commit :dispatch_create_event
  after_update_commit :dispatch_update_event
  after_destroy_commit :invalidate_filtered_unread_counts_after_destroy

  scope :order_by_name, -> { order('lower(name) ASC') }

  # Adds multiple members to the inbox
  # @param user_ids [Array<Integer>] Array of user IDs to add as members
  # @return [void]
  def add_members(user_ids)
    inbox_members.create!(user_ids.map { |user_id| { user_id: user_id } })
    update_account_cache
  end

  # Removes multiple members from the inbox
  # @param user_ids [Array<Integer>] Array of user IDs to remove
  # @return [void]
  def remove_members(user_ids)
    inbox_members.where(user_id: user_ids).destroy_all
    update_account_cache
  end

  # Updates teams linked to the inbox and syncs collaborators from team members.
  # @param team_ids [Array<Integer>] Array of team IDs to link
  # @return [void]
  def update_teams(team_ids)
    normalized_team_ids = Array(team_ids).map(&:to_i).uniq
    valid_team_ids = account.teams.where(id: normalized_team_ids).pluck(:id)
    current_team_ids = inbox_teams.pluck(:team_id)

    to_add = valid_team_ids - current_team_ids
    to_remove = current_team_ids - valid_team_ids

    ActiveRecord::Base.transaction do
      to_add.each { |team_id| inbox_teams.create!(team_id: team_id) }
      inbox_teams.where(team_id: to_remove).delete_all
    end

    Inboxes::MembersSyncService.new(inbox: self).perform
  end

  def assignable_agents
    (account.users.where(id: members.select(:user_id)) + account.administrators).uniq
  end

  def inbox_type
    channel.name
  end

  def webhook_data
    {
      id: id,
      name: name
    }
  end

  def member_ids_with_assignment_capacity
    members.ids
  end

  def auto_assignment_v2_enabled?
    account.feature_enabled?('assignment_v2')
  end

  # Callers (Reauthorizable) only invoke this on a real transition, so the previous
  # value is always the inverse of the new boolean value.
  def dispatch_reauthorization_event(reauthorization_required)
    return if ENV['ENABLE_INBOX_EVENTS'].blank?

    changed_attributes = { reauthorization_required: [!reauthorization_required, reauthorization_required] }
    Rails.configuration.dispatcher.dispatch(INBOX_UPDATED, Time.zone.now, inbox: self, changed_attributes: changed_attributes)
  end

  private

  def dispatch_create_event
    return if ENV['ENABLE_INBOX_EVENTS'].blank?

    Rails.configuration.dispatcher.dispatch(INBOX_CREATED, Time.zone.now, inbox: self)
  end

  def dispatch_update_event
    return if ENV['ENABLE_INBOX_EVENTS'].blank?

    Rails.configuration.dispatcher.dispatch(INBOX_UPDATED, Time.zone.now, inbox: self, changed_attributes: previous_changes)
  end

  def ensure_valid_max_assignment_limit
    # overridden in enterprise/app/models/enterprise/inbox.rb
  end

  def delete_round_robin_agents
    ::AutoAssignment::InboxRoundRobinService.new(inbox: self).clear_queue
  end

  def capture_filtered_unread_count_user_ids
    return if account.blank?

    @filtered_unread_count_user_ids = (inbox_members.pluck(:user_id) + account.account_users.administrator.pluck(:user_id)).uniq
  end

  def invalidate_filtered_unread_counts_after_destroy
    invalidator = ::Conversations::UnreadCounts::FilteredCountInvalidator.new(account)
    invalidator.conversation_changed!
    invalidator.users_visibility_changed!(user_ids: @filtered_unread_count_user_ids)
  end

  def check_channel_type?
    ['Channel::Email', 'Channel::Api', 'Channel::WebWidget'].include?(channel_type)
  end
end

Inbox.prepend_mod_with('Inbox')
Inbox.include_mod_with('Audit::Inbox')
Inbox.include_mod_with('Concerns::Inbox')
