class ContactMergeAction
  include Events::Types
  pattr_initialize [:account!, :base_contact!, :mergee_contact!]

  def perform
    # This case happens when an agent updates a contact email in dashboard,
    # while the contact also update his email via email collect box
    return @base_contact if base_contact.id == mergee_contact.id

    ActiveRecord::Base.transaction do
      validate_contacts
      merge_conversations
      merge_messages
      merge_contact_inboxes
      merge_contact_notes
      merge_calls
      merge_and_remove_mergee_contact
    end
    @base_contact
  end

  private

  def validate_contacts
    return if belongs_to_account?(@base_contact) && belongs_to_account?(@mergee_contact)

    raise StandardError, 'contact does not belong to the account'
  end

  def belongs_to_account?(contact)
    @account.id == contact.account_id
  end

  def merge_conversations
    Conversation.where(contact_id: @mergee_contact.id).update(contact_id: @base_contact.id)
  end

  def merge_contact_notes
    Note.where(contact_id: @mergee_contact.id, account_id: @mergee_contact.account_id).update(contact_id: @base_contact.id)
  end

  def merge_messages
    Message.where(sender: @mergee_contact).update(sender: @base_contact)
  end

  def merge_contact_inboxes
    @mergee_contact.contact_inboxes.find_each { |contact_inbox| migrate_contact_inbox(contact_inbox) }
  end

  def migrate_contact_inbox(contact_inbox)
    contact_inbox.contact_id = @base_contact.id
    return if contact_inbox.save

    rehome_conversations_on_conflict(contact_inbox)
  end

  def rehome_conversations_on_conflict(contact_inbox)
    target_contact_inbox = @base_contact.contact_inboxes.find_by(inbox_id: contact_inbox.inbox_id)

    raise ActiveRecord::RecordInvalid, contact_inbox if target_contact_inbox.blank?

    Conversation.where(contact_inbox_id: contact_inbox.id)
                .update_all(contact_id: @base_contact.id, contact_inbox_id: target_contact_inbox.id) # rubocop:disable Rails/SkipsModelValidations
  end

  def merge_calls
    # overridden in enterprise/app/actions/enterprise/contact_merge_action.rb
  end

  def merge_and_remove_mergee_contact
    mergable_attribute_keys = %w[identifier name email phone_number additional_attributes custom_attributes]
    base_contact_attributes = base_contact.attributes.slice(*mergable_attribute_keys).compact_blank
    mergee_contact_attributes = mergee_contact.attributes.slice(*mergable_attribute_keys).compact_blank

    # attributes in base contact are given preference
    merged_attributes = mergee_contact_attributes.deep_merge(base_contact_attributes)

    @mergee_contact.reload.destroy!
    Rails.configuration.dispatcher.dispatch(CONTACT_MERGED, Time.zone.now, contact: @base_contact,
                                                                           tokens: [@base_contact.contact_inboxes.filter_map(&:pubsub_token)])
    @base_contact.update!(merged_attributes)
  end
end

ContactMergeAction.prepend_mod_with('ContactMergeAction')
