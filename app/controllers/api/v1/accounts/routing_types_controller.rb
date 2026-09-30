class Api::V1::Accounts::RoutingTypesController < Api::V1::Accounts::BaseController
  before_action :fetch_routing_type, only: [:update, :destroy]

  def index
    @routing_types = Current.account.routing_types
  end

  def create
    @routing_type = Current.account.routing_types.create!(routing_type_params)
  end

  def update
    @routing_type.update!(routing_type_params)
  end

  def destroy
    @routing_type.destroy!
    head :ok
  end

  private

  def routing_type_params
    params.require(:routing_type).permit(:name, :attribute_key, :attribute_value)
  end

  def fetch_routing_type
    @routing_type = Current.account.routing_types.find(params[:id])
  end
end
