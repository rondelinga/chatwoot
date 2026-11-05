module EmailUniquePerInbox
  extend ActiveSupport::Concern

  private

  def email_unique_per_inbox
    return if email.blank?

    conflict = contact_inboxes.any? do |contact_inbox|
      email_conflict_in_inbox?(email: email, inbox_id: contact_inbox.inbox_id, except_contact_id: id)
    end

    errors.add(:email, I18n.t('errors.contacts.email.already_exists_in_inbox')) if conflict
  end

  def email_conflict_in_inbox?(email:, inbox_id:, except_contact_id:)
    Contact
      .joins(:contact_inboxes)
      .where('lower(contacts.email) = ?', email.downcase)
      .where(contact_inboxes: { inbox_id: inbox_id })
      .where.not(contacts: { id: except_contact_id })
      .exists?
  end
end
