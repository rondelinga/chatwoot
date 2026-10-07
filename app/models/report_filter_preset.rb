# == Schema Information
#
# Table name: report_filter_presets
#
#  id         :bigint           not null, primary key
#  filters    :jsonb            not null
#  name       :string           not null
#  section    :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  idx_report_filter_presets_unique_name  (account_id,user_id,name) UNIQUE
#
class ReportFilterPreset < ApplicationRecord
  belongs_to :account
  belongs_to :user

  validates :name, presence: true, length: { maximum: 100 }
  validates :section, length: { maximum: 64 }, format: { with: /\A[a-z0-9_]+\z/ }, allow_blank: true
  validates :name, uniqueness: { scope: [:account_id, :user_id] }
end
