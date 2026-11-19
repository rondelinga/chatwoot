# == Schema Information
#
# Table name: canned_responses
#
#  id            :integer          not null, primary key
#  content       :text
#  short_code    :string
#  visibility    :integer          default("public_response"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :integer          not null
#  created_by_id :integer
#
# Indexes
#
#  index_canned_responses_on_created_by_id  (created_by_id)
#  index_canned_responses_on_visibility     (visibility)
#

class CannedResponse < ApplicationRecord
  include AccountCacheRevalidator
  include CannedResponseAccess

  validates :content, presence: true
  validates :short_code, presence: true
  validates :account, presence: true

  belongs_to :account

  scope :order_by_search, lambda { |search|
    short_code_starts_with = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 1', "#{search}%"])
    short_code_like = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 0.5', "%#{search}%"])
    content_like = sanitize_sql_array(['WHEN content ILIKE ? THEN 0.2', "%#{search}%"])
    order_clause = "CASE #{short_code_starts_with} #{short_code_like} #{content_like} ELSE 0 END"
    order(Arel.sql(order_clause) => :desc)
  }
end
