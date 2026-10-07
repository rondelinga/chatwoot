class MessageTemplates::Template::CsatLikeDislikeHint
  pattr_initialize [:conversation!]

  def perform
    return unless hint_enabled?

    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :template,
      content: csat_config['like_dislike_hint_message'].presence || I18n.t('conversations.templates.csat_like_dislike_hint')
    )
  end

  private

  delegate :inbox, to: :conversation
  delegate :csat_config, to: :inbox

  def hint_enabled?
    inbox.csat_survey_enabled? &&
      csat_config['display_type'] == 'like_dislike' &&
      csat_config['like_dislike_hint_enabled'] != false
  end
end
