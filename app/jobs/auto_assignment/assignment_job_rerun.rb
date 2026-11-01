# Upstream coalesces AssignmentJob per inbox: while one is queued or running, new triggers are
# dropped. A conversation created after the running job has loaded its unassigned list is then
# left unassigned until the next trigger or the periodic job (up to 30 minutes).
# A dropped trigger now leaves a rerun mark, and the running job enqueues one more pass when it ends.
module AutoAssignment::AssignmentJobRerun
  RERUN_KEY = 'AUTO_ASSIGNMENT_RERUN::%<inbox_id>d'.freeze

  def self.install!
    job = AutoAssignment::AssignmentJob
    job.singleton_class.prepend(ClassMethods) unless job.singleton_class.include?(ClassMethods)
    job.prepend(InstanceMethods) unless job.include?(InstanceMethods)
  end

  def self.rerun_key(inbox_id)
    format(RERUN_KEY, inbox_id: inbox_id)
  end

  module ClassMethods
    # When the inbox is busy, leave the mark and try the gate once more: if the running job released
    # the gate before it could see the mark, this second try enqueues the pass instead.
    def enqueue_for_inbox(inbox_id)
      return true if super

      ::Redis::Alfred.set(AutoAssignment::AssignmentJobRerun.rerun_key(inbox_id), 1, ex: self::IN_FLIGHT_TTL)
      super
    end

    # A rerun leaves no mark of its own, otherwise every pass would schedule the next one
    def enqueue_rerun_for_inbox(inbox_id)
      method(:enqueue_for_inbox).super_method.call(inbox_id)
    end
  end

  module InstanceMethods
    def perform(inbox_id:, token: nil)
      super
    ensure
      rerun_key = AutoAssignment::AssignmentJobRerun.rerun_key(inbox_id)
      self.class.enqueue_rerun_for_inbox(inbox_id) if ::Redis::Alfred.delete(rerun_key).to_i.positive?
    end
  end
end
