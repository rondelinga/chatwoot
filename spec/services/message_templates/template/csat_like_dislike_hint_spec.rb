require 'rails_helper'

describe MessageTemplates::Template::CsatLikeDislikeHint do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, csat_survey_enabled: true, csat_config: csat_config) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:csat_config) { { 'display_type' => 'like_dislike' } }
  let(:service) { described_class.new(conversation: conversation) }

  describe '#perform' do
    it 'creates the default hint as a template message' do
      service.perform

      hint = conversation.messages.last
      expect(hint.message_type).to eq('template')
      expect(hint.sender).to be_nil
      expect(hint.content).to eq(I18n.t('conversations.templates.csat_like_dislike_hint'))
    end

    context 'when a custom hint message is configured' do
      let(:csat_config) { { 'display_type' => 'like_dislike', 'like_dislike_hint_message' => 'Rate us anytime' } }

      it 'uses the configured hint' do
        service.perform

        expect(conversation.messages.last.content).to eq('Rate us anytime')
      end
    end

    context 'when the hint is disabled' do
      let(:csat_config) { { 'display_type' => 'like_dislike', 'like_dislike_hint_enabled' => false } }

      it 'does not create a message' do
        expect { service.perform }.not_to(change { conversation.messages.count })
      end
    end

    context 'when the display type is not like_dislike' do
      let(:csat_config) { { 'display_type' => 'emoji' } }

      it 'does not create a message' do
        expect { service.perform }.not_to(change { conversation.messages.count })
      end
    end

    context 'when csat survey is disabled' do
      before { inbox.update!(csat_survey_enabled: false) }

      it 'does not create a message' do
        expect { service.perform }.not_to(change { conversation.messages.count })
      end
    end
  end
end
