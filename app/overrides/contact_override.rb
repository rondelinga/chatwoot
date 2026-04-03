module ContactOverride
  def self.prepended(base)
    base.include(EmailUniquePerInbox)
    base.scope :in_inbox, lambda { |inbox_id|
      joins(:contact_inboxes).where(contact_inboxes: { inbox_id: inbox_id })
    }
    base.after_validation :email_unique_per_inbox, if: :email_changed?
  end

  private

  def email_unique_per_inbox
    return if email.blank?

    conflict = contact_inboxes.any? do |contact_inbox|
      email_conflict_in_inbox?(email: email, inbox_id: contact_inbox.inbox_id, except_contact_id: id)
    end
    errors.add(:email, I18n.t('errors.contacts.email.already_exists_in_inbox')) if conflict
  end
end

Contact.prepend(ContactOverride) unless Contact <= ContactOverride
