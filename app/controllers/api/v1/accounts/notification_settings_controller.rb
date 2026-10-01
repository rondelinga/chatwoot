class Api::V1::Accounts::NotificationSettingsController < Api::V1::Accounts::BaseController
  before_action :set_user, :load_notification_setting

  SOUND_ATTRIBUTES = %i[
    new_conversation_sound_enabled
    new_conversation_sound
    new_conversation_volume
    new_conversation_custom_sound_id
    new_message_sound_enabled
    new_message_sound
    new_message_volume
    new_message_custom_sound_id
  ].freeze

  def show; end

  def update
    update_settings
    @notification_setting.save!
    render action: 'show'
  end

  private

  def set_user
    @user = current_user
  end

  def load_notification_setting
    @notification_setting = @user.notification_settings
                                 .includes(:new_conversation_custom_sound, :new_message_custom_sound)
                                 .find_by(account_id: Current.account.id)
  end

  def notification_setting_params
    params.require(:notification_settings).permit(
      :notification_display_duration,
      :new_conversation_sound_enabled,
      :new_conversation_sound,
      :new_conversation_volume,
      :new_conversation_custom_sound_id,
      :new_message_sound_enabled,
      :new_message_sound,
      :new_message_volume,
      :new_message_custom_sound_id,
      selected_email_flags: [],
      selected_push_flags: []
    )
  end

  def update_settings
    settings_params = notification_setting_params
    if settings_params.key?(:selected_email_flags)
      @notification_setting.selected_email_flags = settings_params[:selected_email_flags]
    end
    if settings_params.key?(:selected_push_flags)
      @notification_setting.selected_push_flags = settings_params[:selected_push_flags]
    end
    if settings_params.key?(:notification_display_duration)
      @notification_setting.notification_display_duration = settings_params[:notification_display_duration]
    end

    SOUND_ATTRIBUTES.each do |attribute|
      next unless settings_params.key?(attribute)

      @notification_setting[attribute] = settings_params[attribute]
    end
  end
end
