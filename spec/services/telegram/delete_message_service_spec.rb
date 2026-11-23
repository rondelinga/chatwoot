require 'rails_helper'

describe Telegram::DeleteMessageService do
  let(:channel) { create(:channel_telegram) }
  let(:conversation) do
    create(:conversation, inbox: channel.inbox,
                          additional_attributes: { 'chat_id' => '123', 'business_connection_id' => 'biz-1' })
  end
  let(:message) do
    create(:message, message_type: :outgoing, content: 'hello', conversation: conversation, source_id: '55')
  end
  let(:endpoint) { "https://api.telegram.org/bot#{channel.bot_token}/deleteMessage" }

  it 'deletes the message in the Telegram chat' do
    stub_request(:post, endpoint)
      .with(body: { 'chat_id' => '123', 'message_id' => '55', 'business_connection_id' => 'biz-1' })
      .to_return(status: 200, body: { ok: true, result: true }.to_json, headers: { 'Content-Type' => 'application/json' })

    described_class.new(message: message).perform

    expect(a_request(:post, endpoint)).to have_been_made
  end

  it 'does not call Telegram for a private note' do
    message.update!(private: true)

    described_class.new(message: message).perform

    expect(a_request(:post, endpoint)).not_to have_been_made
  end

  it 'does not call Telegram when the message was never delivered' do
    message.update!(source_id: nil)

    described_class.new(message: message).perform

    expect(a_request(:post, endpoint)).not_to have_been_made
  end

  it 'treats a message Telegram has already removed as deleted' do
    stub_request(:post, endpoint).to_return(
      status: 400,
      body: { ok: false, description: 'Bad Request: message to delete not found' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    expect { described_class.new(message: message).perform }.not_to raise_error
  end

  it 'raises when Telegram refuses to delete the message' do
    stub_request(:post, endpoint).to_return(
      status: 400,
      body: { ok: false, description: "Bad Request: message can't be deleted" }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    expect { described_class.new(message: message).perform }
      .to raise_error(described_class::Error, "Bad Request: message can't be deleted")
  end
end
