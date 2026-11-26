class Inboxes::BulkTeamAssignmentService
  class Error < StandardError; end

  pattr_initialize [:account!, :sets!]

  def perform
    normalized = normalize_sets
    ActiveRecord::Base.transaction do
      normalized.each { |set| apply_set(set) }
    end
  end

  private

  def normalize_sets
    raise Error, 'Choose at least one set' if Array(sets).blank?

    seen_inbox_ids = []
    Array(sets).map { |set| normalize_set(set, seen_inbox_ids) }
  end

  def normalize_set(set, seen_inbox_ids)
    inbox_ids = account_inbox_ids(set)
    ensure_unique_inboxes!(inbox_ids, seen_inbox_ids)
    configs = team_configs_for(set)

    {
      mode: mode_for(set),
      inbox_ids: inbox_ids,
      team_ids: configs.map { |config| config[:team_id].to_i }.uniq,
      default_team_id: default_team_id(configs)
    }
  end

  def account_inbox_ids(set)
    ids = Array(set[:inbox_ids]).map(&:to_i).uniq
    raise Error, 'Choose at least one inbox' if ids.empty?

    found = account.inboxes.where(id: ids).pluck(:id)
    raise Error, 'Unknown inbox' unless found.size == ids.size

    found
  end

  def ensure_unique_inboxes!(inbox_ids, seen_inbox_ids)
    raise Error, 'An inbox can belong to only one set' if inbox_ids.intersect?(seen_inbox_ids)

    seen_inbox_ids.concat(inbox_ids)
  end

  def team_configs_for(set)
    configs = Array(set[:team_configs])
    raise Error, 'Choose at least one team' if configs.empty?

    ids = configs.map { |config| config[:team_id].to_i }.uniq
    found = account.teams.where(id: ids).pluck(:id)
    raise Error, 'Unknown team' unless found.size == ids.size

    configs
  end

  def default_team_id(configs)
    defaults = configs.select { |config| truthy?(config[:is_default]) }
    raise Error, 'Choose one default team' unless defaults.one?

    defaults.first[:team_id].to_i
  end

  def mode_for(set)
    mode = set[:mode].presence || 'add'
    raise Error, 'Unknown mode' unless %w[add replace].include?(mode)

    mode
  end

  def apply_set(set)
    account.inboxes.where(id: set[:inbox_ids]).find_each do |inbox|
      apply_to_inbox(inbox, set)
    end
  end

  def apply_to_inbox(inbox, set)
    inbox.inbox_teams.where.not(team_id: set[:team_ids]).destroy_all if set[:mode] == 'replace'
    set[:team_ids].each { |team_id| inbox.inbox_teams.find_or_create_by!(team_id: team_id) }
    assign_default(inbox, set[:default_team_id])
  end

  def assign_default(inbox, team_id)
    inbox.inbox_teams.where(is_default: true).where.not(team_id: team_id).find_each do |link|
      link.update!(is_default: false)
    end
    inbox.inbox_teams.find_by!(team_id: team_id).update!(is_default: true)
  end

  def truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end
end
