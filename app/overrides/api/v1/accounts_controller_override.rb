module Api::V1::AccountsControllerOverride
  def update
    @account.assign_attributes(
      account_params.slice(:name, :locale, :domain, :support_email,
                           :queue_enabled, :queue_message,
                           :active_chat_limit_enabled, :active_chat_limit_value)
    )
    @account.custom_attributes.merge!(custom_attributes_params)
    @account.settings.merge!(settings_params)
    @account.custom_attributes['onboarding_step'] = 'invite_team' if @account.custom_attributes['onboarding_step'] == 'account_update'
    @account.save!
  end

  def account_params
    super.merge(
      params.permit(
        :queue_enabled, :queue_message,
        :active_chat_limit_enabled, :active_chat_limit_value
      )
    )
  end
end

Api::V1::AccountsController.prepend(Api::V1::AccountsControllerOverride) unless Api::V1::AccountsController <= Api::V1::AccountsControllerOverride
