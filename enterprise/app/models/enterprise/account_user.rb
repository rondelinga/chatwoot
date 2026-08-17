module Enterprise::AccountUser
  def permissions
    custom_role.present? ? (custom_role.permissions + ['custom_role']) : super
  end

  def custom_role_permission?(*names)
    return false if custom_role.blank?

    (custom_role.permissions & names.flatten.map(&:to_s)).any?
  end

  # Missed calls are pushed by default, alongside the core defaults
  def create_notification_setting
    super
    setting = user.notification_settings.find_by(account_id: account_id)
    setting.push_voice_call_missed = true
    setting.save!
  end
end
