class WalletsController < ApplicationController

  def show
    owner_id, owner_type = params.values_at(:owner_id, :owner_type)
    wallet = WalletsRepository.find(owner_id, owner_type)
    wallet = CreateWalletService.call(owner_type: owner_type, owner_id: owner_id) unless wallet

    render json: wallet
  end

end
