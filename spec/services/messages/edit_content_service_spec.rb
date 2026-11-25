require 'rails_helper'

describe Messages::EditContentService do
  let(:conversation) { create(:conversation) }
  let(:message) { create(:message, message_type: :outgoing, content: 'hello', conversation: conversation) }

  it 'updates the widget message the contact already has' do
    described_class.new(message: message, content: 'updated').perform

    expect(message.reload.content).to eq('updated')
    expect(message.content_attributes['edited']).to be(true)
  end

  it 'replaces the same Telegram message' do
    channel = create(:channel_telegram)
    conversation = create(:conversation, inbox: channel.inbox, additional_attributes: { 'chat_id' => '123' })
    message = create(:message, message_type: :outgoing, content: 'hello', conversation: conversation, source_id: '55')
    endpoint = "https://api.telegram.org/bot#{channel.bot_token}/editMessageText"
    stub_request(:post, endpoint).to_return(
      status: 200, body: { ok: true, result: true }.to_json, headers: { 'Content-Type' => 'application/json' }
    )

    described_class.new(message: message, content: 'updated').perform

    expect(message.reload.content).to eq('updated')
    expect(a_request(:post, endpoint).with(body: hash_including('text' => 'updated', 'message_id' => '55'))).to have_been_made
  end

  it 'leaves a delivered WhatsApp message unchanged' do
    channel = create(:channel_whatsapp, sync_templates: false, validate_provider_config: false)
    conversation = create(:conversation, inbox: channel.inbox)
    message = create(:message, message_type: :outgoing, content: 'hello', conversation: conversation, source_id: 'wamid.1')

    expect { described_class.new(message: message, content: 'updated').perform }
      .to raise_error(described_class::Error, 'This channel cannot change a message the contact already received')
    expect(message.reload.content).to eq('hello')
  end

  it 'rejects an edit after the window' do
    message.update_columns(created_at: 16.minutes.ago) # rubocop:disable Rails/SkipsModelValidations

    expect { described_class.new(message: message, content: 'updated').perform }
      .to raise_error(described_class::Error, 'This message can only be edited within 15 minutes of sending')
  end

  it 'corrects a message that never reached the contact' do
    channel = create(:channel_whatsapp, sync_templates: false, validate_provider_config: false)
    conversation = create(:conversation, inbox: channel.inbox)
    message = create(:message, message_type: :outgoing, content: 'hello', status: :failed, conversation: conversation, source_id: nil)

    described_class.new(message: message, content: 'updated').perform

    expect(message.reload.content).to eq('updated')
  end
end
