class DashboardController < ApplicationController
  def show
    result = DashboardService.call(params[:id])
    return render(json: { error: "Organization not found" }, status: :not_found) unless result

    render json: result
  end
end
