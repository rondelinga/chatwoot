class CannedResponses::SaveService
  Result = Struct.new(:canned_response, :error, keyword_init: true)
  MISSING_SCOPE_ERROR = 'Private canned response must be assigned to a user, team, or inbox'.freeze

  def initialize(account:, user:, attributes:, scope_ids:, canned_response: nil)
    @account = account
    @user = user
    @attributes = attributes
    @scope_ids = scope_ids
    @canned_response = canned_response
  end

  def perform
    @canned_response ? update_response : create_response
  end

  private

  def create_response
    response = find_or_init
    response.assign_attributes(@attributes.merge(created_by_id: @user.id))
    return missing_scope if response.private_response? && no_scopes_provided?

    is_new = response.new_record?
    response.save!
    response.canned_response_scopes.destroy_all unless is_new
    build_scopes(response)
    Result.new(canned_response: response)
  end

  def update_response
    @canned_response.update!(@attributes)
    @canned_response.canned_response_scopes.destroy_all
    return missing_scope if @canned_response.private_response? && no_scopes_provided?

    build_scopes(@canned_response)
    Result.new(canned_response: @canned_response)
  end

  def find_or_init
    visibility = @attributes[:visibility]
    short_code = @attributes[:short_code]

    if visibility == 'private_response'
      @account.canned_responses.find_or_initialize_by(
        short_code: short_code,
        visibility: :private_response,
        created_by_id: @user.id
      )
    else
      @account.canned_responses.find_or_initialize_by(
        short_code: short_code,
        visibility: :public_response
      )
    end
  end

  def build_scopes(canned_response)
    return unless canned_response.private_response?

    canned_response.canned_response_scopes.create!(
      user_ids: scope_user_ids,
      team_ids: scope_team_ids,
      inbox_ids: scope_inbox_ids
    )
  end

  def scope_user_ids
    return [@user.id] unless @user.administrator?

    Array(@scope_ids[:user_ids]).map(&:to_i)
  end

  def scope_team_ids
    return [] unless @user.administrator?

    Array(@scope_ids[:team_ids]).map(&:to_i)
  end

  def scope_inbox_ids
    Array(@scope_ids[:inbox_ids]).map(&:to_i)
  end

  def no_scopes_provided?
    return false unless @user.administrator?

    scope_user_ids.empty? && scope_team_ids.empty? && scope_inbox_ids.empty?
  end

  def missing_scope
    Result.new(error: MISSING_SCOPE_ERROR)
  end
end
