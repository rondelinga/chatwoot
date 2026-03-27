module Overrides
  module ContactInboxOverride
    def self.prepended(base)
      base.include(EmailUniquePerInbox)
      base.validate :email_unique_per_inbox
    end

    private

    def email_unique_per_inbox
      return if contact&.email.blank?

      if email_conflict_in_inbox?(
        email: contact.email,
        inbox_id: inbox_id,
        except_contact_id: contact.id
      )
        errors.add(:base, I18n.t('errors.contacts.email.already_exists_in_inbox'))
      end
    end
  end
end

ContactInbox.prepend(Overrides::ContactInboxOverride)
