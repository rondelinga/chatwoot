module AccountSettingsAccessors
  extend ActiveSupport::Concern

  included do
    store_accessor :settings, :auto_resolve_after, :auto_resolve_message, :auto_resolve_ignore_waiting,
                   :auto_resolve_message_agent, :auto_resolve_message_client, :auto_resolve_split_reasons,
                   :auto_resolve_pending_after, :auto_resolve_pending_message
    store_accessor :settings, :audio_transcriptions, :auto_resolve_label
    store_accessor :settings, :captain_models, :captain_features
    store_accessor :settings, :agent_history_days
    store_accessor :settings, :busy_to_offline_timeout
    store_accessor :settings, :reporting_timezone
    store_accessor :settings, :keep_pending_on_bot_failure
    store_accessor :settings, :captain_auto_resolve_mode
    store_accessor :settings, :enforce_mfa
  end

  def enforce_mfa?
    Chatwoot.mfa_enabled? && enforce_mfa == true
  end

  def inbound_email_domain
    domain.presence || GlobalConfig.get('MAILER_INBOUND_EMAIL_DOMAIN')['MAILER_INBOUND_EMAIL_DOMAIN'] || ENV.fetch('MAILER_INBOUND_EMAIL_DOMAIN',
                                                                                                                   false)
  end

  def support_email
    super.presence || ENV.fetch('MAILER_SENDER_EMAIL') { GlobalConfig.get('MAILER_SUPPORT_EMAIL')['MAILER_SUPPORT_EMAIL'] }
  end

  private

  def validate_reporting_timezone
    return if reporting_timezone.blank? || ActiveSupport::TimeZone[reporting_timezone].present?

    errors.add(:reporting_timezone, I18n.t('errors.account.reporting_timezone.invalid'))
  end

  def validate_support_email_format
    value = attributes['support_email']
    return if value.blank?

    parsed = Mail::Address.new(value).address
    errors.add(:support_email, I18n.t('errors.account.support_email.invalid')) if parsed.blank?
  rescue Mail::Field::ParseError, Mail::Field::IncompleteParseError
    errors.add(:support_email, I18n.t('errors.account.support_email.invalid'))
  end
end
