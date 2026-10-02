module Search::InboxAccess
  private

  def apply_inbox_id_filter(query)
    return query if params[:inbox_id].blank?

    inbox_id = params[:inbox_id].to_i
    return query if inbox_id.zero? || !validate_inbox_access(inbox_id)

    query.where(inbox_id: inbox_id)
  end

  def validate_inbox_access(inbox_id)
    should_skip_inbox_filtering? || accessable_inbox_ids.include?(inbox_id)
  end

  def should_skip_inbox_filtering?
    account_user.administrator? || user_has_access_to_all_inboxes?
  end

  def user_has_access_to_all_inboxes?
    accessable_inbox_ids.sort == current_account.inboxes.pluck(:id).sort
  end
end
