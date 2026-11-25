require 'rails_helper'

describe Telegram::EditMessageService do
  let(:channel) { create(:channel_telegram) }
  let(:conversation) do
    create(:conversation, inbox: channel.inbox,
                          additional_attributes: { 'chat_id' => '123', 'business_connection_id' => 'biz-1' })
  end
  let(:message) do
    create(:message, message_type: :outgoing, content: 'hello', conversation: conversation, source_id: '55')
  end
  let(:endpoint) { "https://api.telegram.org/bot#{channel.bot_token}/editMessageText" }

  it 'replaces the text in the Telegram chat' do
    stub_request(:post, endpoint)
      .with(body: { 'chat_id' => '123', 'message_id' => '55', 'text' => 'updated', 'business_connection_id' => 'biz-1' })
      .to_return(status: 200, body: { ok: true, result: true }.to_json, headers: { 'Content-Type' => 'application/json' })

    described_class.new(message: message, content: 'updated').perform

    expect(a_request(:post, endpoint)).to have_been_made
  end

  it 'raises when Telegram refuses the edit' do
    stub_request(:post, endpoint).to_return(
      status: 400,
      body: { ok: false, description: "Bad Request: message can't be edited" }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    expect { described_class.new(message: message, content: 'updated').perform }
      .to raise_error(described_class::Error, "Bad Request: message can't be edited")
  end
end
