class CannedResponses::DestroyService
  def initialize(canned_response:, user:)
    @canned_response = canned_response
    @user = user
  end

  def perform
    if @canned_response.private_response?
      remove_user_from_scopes_or_destroy
    else
      @canned_response.destroy!
    end
  end

  private

  def remove_user_from_scopes_or_destroy
    scope = @canned_response.canned_response_scopes.find do |canned_scope|
      canned_scope.user_ids.include?(@user.id)
    end

    remove_user_from(scope) if scope
    @canned_response.destroy! if @canned_response.reload.canned_response_scopes.empty?
  end

  def remove_user_from(scope)
    updated_user_ids = scope.user_ids - [@user.id]
    if updated_user_ids.empty?
      scope.destroy!
    else
      scope.update!(user_ids: updated_user_ids)
    end
  end
end
