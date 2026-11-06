module Api::V1::Accounts::Concerns::InboxBrandedEmailLayout
  private

  def update_branded_email_layout
    return true unless params.key?(:branded_email_layout)

    branded_email_layout = normalized_branded_email_layout

    unless Current.account.feature_enabled?(:branded_email_templates)
      return true if branded_email_layout.blank?

      render_could_not_create_error('Branded email templates feature is not enabled')
      return false
    end

    unless @inbox.email?
      return true if branded_email_layout.blank?

      render_could_not_create_error('Branded email layout is only supported for email inboxes')
      return false
    end

    @inbox.update_branded_email_layout!(branded_email_layout)
    true
  rescue ActiveRecord::RecordInvalid => e
    render_could_not_create_error(e.record.errors.full_messages.join(', '))
    false
  end

  def normalized_branded_email_layout
    params[:branded_email_layout] == 'null' ? nil : params[:branded_email_layout]
  end
end
