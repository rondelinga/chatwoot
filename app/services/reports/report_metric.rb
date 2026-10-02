# Describes one public report metric.
# name: API-facing metric name requested by reports.
# aggregate: whether the metric is a count or average.
# raw_event_name: source reporting_events name for raw queries.
# rollup_metric: source reporting_events_rollups metric for rollup queries.
# summary_key: key used when this metric appears in grouped summary responses.
# raw_count_strategy: optional raw-query counting rule, such as distinct conversations.
Reports::ReportMetric = Data.define(
  :name,
  :aggregate,
  :raw_event_name,
  :rollup_metric,
  :summary_key,
  :raw_count_strategy
) do
  def self.build(attrs)
    new(
      name: attrs.fetch(:name),
      aggregate: attrs.fetch(:aggregate),
      raw_event_name: attrs[:raw_event_name],
      rollup_metric: attrs[:rollup_metric],
      summary_key: attrs[:summary_key],
      raw_count_strategy: attrs[:raw_count_strategy]
    )
  end

  def average?
    aggregate == :average
  end

  def count?
    aggregate == :count
  end

  def rollup_supported?
    rollup_metric.present?
  end

  def summary?
    summary_key.present?
  end
end
