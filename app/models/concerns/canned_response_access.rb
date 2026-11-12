module CannedResponseAccess
  extend ActiveSupport::Concern

  ACCESSIBLE_TO = lambda { |user, inbox_id: nil|
    private_accessible_ids = where(visibility: :private_response)
                             .joins(:canned_response_scopes)
                             .where(
                               'canned_response_scopes.user_ids @> ARRAY[:user_id]::integer[]',
                               user_id: user.id
                             )
                             .then do |scope|
                               if inbox_id.present?
                                 scope.where(
                                   "canned_response_scopes.inbox_ids = '{}' OR " \
                                   'canned_response_scopes.inbox_ids @> ARRAY[:inbox_id]::integer[]',
                                   inbox_id: inbox_id
                                 )
                               else
                                 scope
                               end
                             end
                             .distinct.pluck(:id)

    where(visibility: :public_response).or(where(id: private_accessible_ids))
  }

  LISTED_FOR = lambda { |user, include_all: false, inbox_id: nil, search: nil|
    relation = if include_all
                 user.administrator? ? all : where(created_by_id: user.id).or(accessible_to(user))
               else
                 accessible_to(user, inbox_id: inbox_id)
               end
    relation = relation.includes(:canned_response_scopes)
    next relation unless search

    term = search.delete("\0")
    relation.where('short_code ILIKE :search OR content ILIKE :search', search: "%#{term}%")
            .order_by_search(term)
  }

  included do
    enum visibility: { public_response: 0, private_response: 1 }

    belongs_to :created_by, class_name: 'User', optional: true
    has_many :canned_response_scopes, dependent: :destroy

    scope :accessible_to, ACCESSIBLE_TO
    scope :listed_for, LISTED_FOR
  end
end
