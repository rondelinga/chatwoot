module InboxNameSanitizer
  extend ActiveSupport::Concern

  # Sanitizes inbox name for balanced email provider compatibility
  # ALLOWS: /'._- and Unicode letters/numbers/emojis
  # REMOVES: Forbidden chars (\<>@"()) + spam-trigger symbols (!#$%&*+=?^`{|}~)
  def sanitized_name
    return default_name_for_blank_name if name.blank?

    sanitized = apply_sanitization_rules(name)
    sanitized.blank? && email? ? display_name_from_email : sanitized
  end

  def sanitized_business_name
    sanitize_raw_name(business_name) || sanitized_name
  end

  def display_name
    public_name.presence || name
  end

  private

  def default_name_for_blank_name
    email? ? display_name_from_email : ''
  end

  def sanitize_raw_name(raw)
    return nil if raw.blank?

    apply_sanitization_rules(raw).presence
  end

  def apply_sanitization_rules(name)
    name.gsub(/[\\<>@"!#$%&*+=?^`{|}~:;()]/, '')
        .gsub(/[\x00-\x1F\x7F]/, ' ')
        .gsub(/\A[[:punct:]]+|[[:punct:]]+\z/, '')
        .gsub(/\s+/, ' ')
        .strip
  end

  def display_name_from_email
    channel.email.split('@').first.parameterize.titleize
  end
end
