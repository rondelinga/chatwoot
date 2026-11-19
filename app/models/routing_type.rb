# == Schema Information
#
# Table name: routing_types
#
#  id              :bigint           not null, primary key
#  attribute_key   :string           not null
#  attribute_value :string           not null
#  name            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#
# Indexes
#
#  idx_routing_types_unique_attr      (account_id,attribute_key,attribute_value) UNIQUE
#  index_routing_types_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class RoutingType < ApplicationRecord
  belongs_to :account
  has_many :inbox_teams, dependent: :nullify
  validates :name, presence: true
  validates :attribute_key, :attribute_value, presence: true
end
