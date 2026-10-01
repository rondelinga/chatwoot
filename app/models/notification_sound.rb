# == Schema Information
#
# Table name: notification_sounds
#
#  id         :bigint           not null, primary key
#  filename   :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#

class NotificationSound < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :user
  has_one_attached :file

  validates :filename, presence: true
  validates :file, presence: true

  def file_url
    return if file.blank?

    if ActiveStorage::Current.url_options.blank?
      ActiveStorage::Current.url_options = Rails.application.routes.default_url_options
    end
    url_for(file)
  end

  def push_event_data
    {
      id: id,
      filename: filename,
      byte_size: file.attached? ? file.byte_size : 0,
      url: file_url
    }
  end
end
