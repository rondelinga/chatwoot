class RoutingType < ApplicationRecord
  belongs_to :account
  has_many :inbox_teams, dependent: :nullify
  validates :name, presence: true
  validates :attribute_key, :attribute_value, presence: true
end
