module AccountChannelAssociations
  extend ActiveSupport::Concern

  included do
    has_many :api_channels, dependent: :destroy_async, class_name: '::Channel::Api'
    has_many :email_channels, dependent: :destroy_async, class_name: '::Channel::Email'
    has_many :facebook_pages, dependent: :destroy_async, class_name: '::Channel::FacebookPage'
    has_many :instagram_channels, dependent: :destroy_async, class_name: '::Channel::Instagram'
    has_many :tiktok_channels, dependent: :destroy_async, class_name: '::Channel::Tiktok'
    has_many :line_channels, dependent: :destroy_async, class_name: '::Channel::Line'
    has_many :sms_channels, dependent: :destroy_async, class_name: '::Channel::Sms'
    has_many :telegram_channels, dependent: :destroy_async, class_name: '::Channel::Telegram'
    has_many :twilio_sms, dependent: :destroy_async, class_name: '::Channel::TwilioSms'
    has_many :twitter_profiles, dependent: :destroy_async, class_name: '::Channel::TwitterProfile'
    has_many :web_widgets, dependent: :destroy_async, class_name: '::Channel::WebWidget'
    has_many :whatsapp_channels, dependent: :destroy_async, class_name: '::Channel::Whatsapp'
  end
end
