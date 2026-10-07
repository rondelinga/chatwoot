# Adds the fork-specific CSAT settings (like/dislike hint, message and on-resolve toggles)
# on top of upstream's InboxesController#format_csat_config.
module InboxCsatConfig
  BOOLEAN_SETTINGS = %w[message_enabled csat_on_resolve_enabled like_dislike_hint_enabled].freeze

  private

  def format_csat_config(config)
    formatted = super
    BOOLEAN_SETTINGS.each { |key| formatted[key] = config.key?(key) ? config[key] : true }
    formatted['like_dislike_hint_message'] = config['like_dislike_hint_message'] || ''
    formatted
  end
end
