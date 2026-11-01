module Enterprise::Concerns::AssignmentPolicy
  extend ActiveSupport::Concern

  included do
    enum assignment_order: { round_robin: 0, balanced: 1, least_busy: 2 } if ChatwootApp.enterprise?
  end
end
