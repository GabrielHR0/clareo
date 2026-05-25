class WalletsController < ApplicationController

   def show
    owner_id, owner_type = params.values_at(:owner_id, :owner_type)
   wallet = WalletsRepository.find(params[:owner_id], params[:owner_type])

   return render json: { error: "wallet_not_found" }, status: :not_found unless wallet

    render json: wallet
   end

end
