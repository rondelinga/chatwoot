module ContactIdentifyActionOverride
  def initialize(contact:, params:, retain_original_contact_name: false, discard_invalid_attrs: false, inbox_id: nil)
    super(contact: contact, params: params,
          retain_original_contact_name: retain_original_contact_name,
          discard_invalid_attrs: discard_invalid_attrs)
    @inbox_id = inbox_id
  end

  private

  def inbox_id
    @inbox_id
  end

  def existing_email_contact
    return if params[:email].blank?

    @existing_email_contact ||= if inbox_id.present?
                                  account.contacts.in_inbox(inbox_id).from_email(params[:email])
                                else
                                  account.contacts.from_email(params[:email])
                                end
  end
end

ContactIdentifyAction.prepend(ContactIdentifyActionOverride) unless ContactIdentifyAction <= ContactIdentifyActionOverride
