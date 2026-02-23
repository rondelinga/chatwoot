class CannedResponseScope < ApplicationRecord
  belongs_to :canned_response
  belongs_to :user, optional: true
  belongs_to :team, optional: true
  belongs_to :inbox, optional: true
end
