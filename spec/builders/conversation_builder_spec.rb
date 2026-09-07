require 'rails_helper'

describe ConversationBuilder do
  let(:account) { create(:account) }
  let!(:sms_channel) { create(:channel_sms, account: account) }
  let!(:api_channel) { create(:channel_api, account: account) }
  let!(:sms_inbox) { create(:inbox, channel: sms_channel, account: account) }
  let!(:api_inbox) { create(:inbox, channel: api_channel, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_sms_inbox) { create(:contact_inbox, contact: contact, inbox: sms_inbox) }
  let(:contact_api_inbox) { create(:contact_inbox, contact: contact, inbox: api_inbox) }

  describe '#perform' do
    it 'creates sms conversation' do
      conversation = described_class.new(
        contact_inbox: contact_sms_inbox,
        params: {}
      ).perform

      expect(conversation.contact_inbox_id).to eq(contact_sms_inbox.id)
    end

    it 'creates api conversation' do
      conversation = described_class.new(
        contact_inbox: contact_api_inbox,
        params: {}
      ).perform

      expect(conversation.contact_inbox_id).to eq(contact_api_inbox.id)
    end

    context 'when lock_to_single_conversation is true for sms inbox' do
      before do
        sms_inbox.update!(lock_to_single_conversation: true)
      end

      it 'creates sms conversation when existing conversation is not present' do
        conversation = described_class.new(
          contact_inbox: contact_sms_inbox,
          params: {}
        ).perform

        expect(conversation.contact_inbox_id).to eq(contact_sms_inbox.id)
      end

      it 'returns last from existing sms conversations when existing conversation is not present' do
        create(:conversation, contact_inbox: contact_sms_inbox)
        existing_conversation = create(:conversation, contact_inbox: contact_sms_inbox)
        conversation = described_class.new(
          contact_inbox: contact_sms_inbox,
          params: {}
        ).perform

        expect(conversation.id).to eq(existing_conversation.id)
      end
    end

    context 'when lock_to_single_conversation is true for api inbox' do
      before do
        api_inbox.update!(lock_to_single_conversation: true)
      end

      it 'creates conversation when existing api conversation is not present' do
        conversation = described_class.new(
          contact_inbox: contact_api_inbox,
          params: {}
        ).perform

        expect(conversation.contact_inbox_id).to eq(contact_api_inbox.id)
      end

      it 'returns last from existing api conversations when existing conversation is not present' do
        create(:conversation, contact_inbox: contact_api_inbox)
        existing_conversation = create(:conversation, contact_inbox: contact_api_inbox)
        conversation = described_class.new(
          contact_inbox: contact_api_inbox,
          params: {}
        ).perform

        expect(conversation.id).to eq(existing_conversation.id)
      end
    end

    context 'for web widget inbox' do
      let!(:widget_channel) { create(:channel_widget, account: account) }
      let!(:widget_inbox) { create(:inbox, channel: widget_channel, account: account) }
      let(:contact_widget_inbox) { create(:contact_inbox, contact: contact, inbox: widget_inbox) }

      it 'reuses the last non-resolved conversation instead of creating a new one' do
        existing_conversation = create(:conversation, contact_inbox: contact_widget_inbox, status: :open)

        conversation = described_class.new(contact_inbox: contact_widget_inbox, params: {}).perform

        expect(conversation.id).to eq(existing_conversation.id)
      end

      it 'creates a new conversation when the last one is resolved' do
        create(:conversation, contact_inbox: contact_widget_inbox, status: :resolved)

        conversation = described_class.new(contact_inbox: contact_widget_inbox, params: {}).perform

        expect(conversation).to be_persisted
        expect(conversation).to be_open
      end
    end

    context 'for telegram inbox' do
      let!(:telegram_channel) { create(:channel_telegram, account: account) }
      let!(:telegram_inbox) { create(:inbox, channel: telegram_channel, account: account) }
      let(:contact_telegram_inbox) { create(:contact_inbox, contact: contact, inbox: telegram_inbox, source_id: '12345') }

      it 'reuses the last non-resolved conversation instead of creating a new one' do
        existing_conversation = create(:conversation, contact_inbox: contact_telegram_inbox, status: :open,
                                                        additional_attributes: { 'chat_id' => '12345' })

        conversation = described_class.new(contact_inbox: contact_telegram_inbox, params: {}).perform

        expect(conversation.id).to eq(existing_conversation.id)
      end

      it 'creates a new conversation with the chat_id carried over when the last one is resolved' do
        create(:conversation, contact_inbox: contact_telegram_inbox, status: :resolved,
                               additional_attributes: { 'chat_id' => '12345' })

        conversation = described_class.new(contact_inbox: contact_telegram_inbox, params: {}).perform

        expect(conversation).to be_open
        expect(conversation.additional_attributes['chat_id']).to eq('12345')
      end

      it 'falls back to the contact inbox source_id as chat_id when there is no previous conversation' do
        conversation = described_class.new(contact_inbox: contact_telegram_inbox, params: {}).perform

        expect(conversation.additional_attributes['chat_id']).to eq('12345')
      end
    end
  end
end
