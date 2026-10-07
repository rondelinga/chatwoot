class Api::V1::Accounts::ReportFilterPresetsController < Api::V1::Accounts::BaseController
  before_action :set_preset, only: [:update, :destroy]

  def index
    presets = Current.account.report_filter_presets.where(user: Current.user)
    render json: presets.order(:name)
  end

  def create
    preset = Current.account.report_filter_presets.create!(preset_params.merge(user: Current.user))
    render json: preset, status: :created
  end

  def update
    @preset.update!(preset_params.except(:section))
    render json: @preset
  end

  def destroy
    @preset.destroy!
    head :ok
  end

  private

  def set_preset
    @preset = Current.account.report_filter_presets.where(user: Current.user).find(params[:id])
  end

  def preset_params
    source = params.require(:report_filter_preset)
    permitted = source.permit(:name, :section)
    permitted[:name] = permitted[:name].to_s.strip if permitted.key?(:name)
    permitted[:filters] = source[:filters].to_unsafe_h if source.key?(:filters)
    permitted
  end
end
