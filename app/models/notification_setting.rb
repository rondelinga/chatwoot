# == Schema Information
#
# Table name: notification_settings
#
#  id                            :bigint           not null, primary key
#  email_flags                   :integer          default(0), not null
#  new_conversation_custom_sound_id :bigint
#  new_conversation_sound           :string           default("bell"), not null
#  new_conversation_sound_enabled   :boolean          default(TRUE), not null
#  new_conversation_volume          :integer          default(80), not null
#  new_message_custom_sound_id      :bigint
#  new_message_sound                :string           default("pop"), not null
#  new_message_sound_enabled        :boolean          default(TRUE), not null
#  new_message_volume               :integer          default(60), not null
#  notification_display_duration    :integer          default(6)
#  push_flags                       :integer          default(0), not null
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  account_id                       :integer
#  user_id                          :integer
#
# Indexes
#
#  by_account_user  (account_id,user_id) UNIQUE
#

class NotificationSetting < ApplicationRecord
  # used for single column multi flags
  include FlagShihTzu

  BUILTIN_SOUNDS = %w[ding bell chime magic ping pop custom].freeze

  belongs_to :account
  belongs_to :user
  belongs_to :new_conversation_custom_sound, class_name: 'NotificationSound', optional: true
  belongs_to :new_message_custom_sound, class_name: 'NotificationSound', optional: true

  DEFAULT_QUERY_SETTING = {
    flag_query_mode: :bit_operator,
    check_for_column: false
  }.freeze

  EMAIL_NOTIFICATION_FLAGS = ::Notification::NOTIFICATION_TYPES.transform_keys { |key| "email_#{key}".to_sym }.invert.freeze
  PUSH_NOTIFICATION_FLAGS = ::Notification::NOTIFICATION_TYPES.transform_keys { |key| "push_#{key}".to_sym }.invert.freeze

  has_flags EMAIL_NOTIFICATION_FLAGS.merge(column: 'email_flags').merge(DEFAULT_QUERY_SETTING)
  has_flags PUSH_NOTIFICATION_FLAGS.merge(column: 'push_flags').merge(DEFAULT_QUERY_SETTING)

  validates :notification_display_duration, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 60 },
                                            allow_nil: true
  validates :new_conversation_sound, inclusion: { in: BUILTIN_SOUNDS }
  validates :new_message_sound, inclusion: { in: BUILTIN_SOUNDS }
  validates :new_conversation_volume, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :new_message_volume, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :custom_sounds_belong_to_user

  private

  def custom_sounds_belong_to_user
    validate_custom_sound_owner(:new_conversation_custom_sound, :new_conversation_custom_sound_id)
    validate_custom_sound_owner(:new_message_custom_sound, :new_message_custom_sound_id)
  end

  def validate_custom_sound_owner(association, error_key)
    sound = public_send(association)
    return if sound.blank? || sound.user_id == user_id

    errors.add(error_key, :invalid)
  end
end
