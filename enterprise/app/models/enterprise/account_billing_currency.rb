module Enterprise::AccountBillingCurrency
  def billing_currency
    # Feature off => everyone is billed in USD (legacy behaviour).
    return Enterprise::Billing::Currencies::DEFAULT unless Enterprise::Billing::Currencies.enabled?

    stored = custom_attributes&.dig('billing_currency')
    return Enterprise::Billing::Currencies.normalize(stored) if Enterprise::Billing::Currencies.supported?(stored)

    # Existing Stripe customers stay on USD (webhook backfills the real currency);
    # only brand-new accounts infer from locale, so existing pt_BR users aren't charged BRL.
    return Enterprise::Billing::Currencies::DEFAULT if custom_attributes&.dig('stripe_customer_id').present?

    Enterprise::Billing::Currencies.for_locale(locale)
  end

  # New accounts whose locale maps to a non-USD currency get to pick USD or that
  # currency before the Stripe customer is created; everyone else proceeds in USD.
  def billing_currency_selection_required?
    return false unless Enterprise::Billing::Currencies.enabled?
    return false if custom_attributes&.dig('stripe_customer_id').present?
    return false if Enterprise::Billing::Currencies.supported?(custom_attributes&.dig('billing_currency'))

    Enterprise::Billing::Currencies.for_locale(locale) != Enterprise::Billing::Currencies::DEFAULT
  end
end
