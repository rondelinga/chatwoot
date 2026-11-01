require 'rails_helper'

RSpec.describe AutoAssignment::AssignmentJobRerun, type: :job do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:gate_key) { format(Redis::Alfred::AUTO_ASSIGNMENT_IN_FLIGHT_KEY, inbox_id: inbox.id) }
  let(:rerun_key) { described_class.rerun_key(inbox.id) }

  before do
    clear_enqueued_jobs
    Redis::Alfred.delete(gate_key)
    Redis::Alfred.delete(rerun_key)
  end

  after do
    Redis::Alfred.delete(gate_key)
    Redis::Alfred.delete(rerun_key)
  end

  describe '.enqueue_for_inbox' do
    it 'enqueues without a rerun mark when the inbox is free' do
      expect(AutoAssignment::AssignmentJob.enqueue_for_inbox(inbox.id)).to be true

      expect(Redis::Alfred.exists?(rerun_key)).to be false
      expect(AutoAssignment::AssignmentJob).to have_been_enqueued.once
    end

    it 'leaves a rerun mark instead of a second job while one is in flight' do
      Redis::Alfred.set(gate_key, 'running-job', ex: 60)

      expect(AutoAssignment::AssignmentJob.enqueue_for_inbox(inbox.id)).to be false

      expect(Redis::Alfred.exists?(rerun_key)).to be true
      expect(AutoAssignment::AssignmentJob).not_to have_been_enqueued
    end
  end

  describe '#perform' do
    before do
      allow(AutoAssignment::AssignmentService).to receive(:new).and_return(instance_double(AutoAssignment::AssignmentService,
                                                                                           perform_bulk_assignment: 0))
    end

    it 'enqueues one more pass when a trigger was dropped during the run' do
      Redis::Alfred.set(rerun_key, 1, ex: 60)

      AutoAssignment::AssignmentJob.perform_now(inbox_id: inbox.id)

      expect(AutoAssignment::AssignmentJob).to have_been_enqueued.once.with(inbox_id: inbox.id, token: kind_of(String))
      expect(Redis::Alfred.exists?(rerun_key)).to be false
    end

    it 'does not enqueue another pass when nothing was dropped' do
      AutoAssignment::AssignmentJob.perform_now(inbox_id: inbox.id)

      expect(AutoAssignment::AssignmentJob).not_to have_been_enqueued
    end

    it 'does not keep rescheduling itself' do
      Redis::Alfred.set(rerun_key, 1, ex: 60)

      perform_enqueued_jobs(only: AutoAssignment::AssignmentJob) { AutoAssignment::AssignmentJob.perform_later(inbox_id: inbox.id) }

      expect(AutoAssignment::AssignmentJob).to have_been_performed.twice
    end
  end

  it 'assigns a conversation that arrives while the bulk run is in progress' do
    create(:inbox_member, inbox: inbox, user: agent)
    policy = create(:assignment_policy, account: account)
    create(:inbox_assignment_policy, inbox: inbox, assignment_policy: policy)
    account.enable_features!('assignment_v2')
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return({ agent.id.to_s => 'online' })
    late_conversation = nil
    # The contact writes in right after the running pass has loaded its unassigned list
    allow(AutoAssignment::AssignmentService).to receive(:new).and_wrap_original do |build, **args|
      build.call(**args).tap do |service|
        allow(service).to receive(:perform_bulk_assignment).and_wrap_original do |original, **kwargs|
          original.call(**kwargs).tap do
            late_conversation ||= create(:conversation, account: account, inbox: inbox, assignee: nil)
          end
        end
      end
    end

    perform_enqueued_jobs(only: AutoAssignment::AssignmentJob) { AutoAssignment::AssignmentJob.enqueue_for_inbox(inbox.id) }

    expect(late_conversation.reload.assignee).to eq(agent)
  end
end
