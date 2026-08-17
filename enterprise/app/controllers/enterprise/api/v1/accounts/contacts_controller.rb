module Enterprise::Api::V1::Accounts::ContactsController
  private

  def fetch_contacts(contacts)
    super(scope_contacts_for_role(contacts))
  end

  def fetch_contacts_with_has_more(contacts)
    super(scope_contacts_for_role(contacts))
  end

  def fetch_contact
    super
    return unless inbox_scoped_contacts?
    return if @contact.contact_inboxes.exists?(inbox_id: assigned_inbox_ids)

    raise ActiveRecord::RecordNotFound
  end

  def scope_contacts_for_role(contacts)
    return contacts unless inbox_scoped_contacts?

    contacts.joins(:contact_inboxes).where(contact_inboxes: { inbox_id: assigned_inbox_ids }).distinct
  end

  def inbox_scoped_contacts?
    return false if Current.account_user.administrator?
    return false if Current.account_user.custom_role_permission?('contact_manage')

    Current.account_user.custom_role_permission?('contact_inbox_manage')
  end

  def assigned_inbox_ids
    @assigned_inbox_ids ||= Current.user.assigned_inboxes.pluck(:id)
  end
end
