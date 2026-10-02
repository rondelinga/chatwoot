module InboxCsatConfig
  extend ActiveSupport::Concern

  private

  def format_csat_config(config)
    formatted = base_csat_config(config)
    format_template_config(config, formatted)
    formatted
  end

  def base_csat_config(config)
    csat_display_settings(config).merge(
      csat_message_settings(config),
      :survey_rules => csat_survey_rules(config),
      'button_text' => config['button_text'] || 'Please rate us',
      'language' => config['language'] || 'en'
    )
  end

  def csat_display_settings(config)
    { 'display_type' => config['display_type'] || 'emoji' }
  end

  def csat_message_settings(config)
    {
      'message' => config['message'] || '',
      'message_enabled' => csat_boolean_setting(config, 'message_enabled', true),
      'csat_on_resolve_enabled' => csat_boolean_setting(config, 'csat_on_resolve_enabled', true),
      'like_dislike_hint_message' => config['like_dislike_hint_message'] || '',
      'like_dislike_hint_enabled' => csat_boolean_setting(config, 'like_dislike_hint_enabled', true)
    }
  end

  def csat_survey_rules(config)
    {
      'operator' => config.dig('survey_rules', 'operator') || 'contains',
      'values' => config.dig('survey_rules', 'values') || []
    }
  end

  def csat_boolean_setting(config, key, default)
    config.key?(key) ? config[key] : default
  end

  def format_template_config(config, formatted)
    formatted['template'] = config['template'] if config['template'].present?
  end
end
