class PaymentMethodsController < ApplicationController
  # POST /owners/:owner_type/:owner_id/payment_methods
  def create
    owner_type = params[:owner_type]
    owner_id = params[:owner_id]
    method_type = params[:method_type]
    details = params[:details] || {}
    is_default = params[:is_default] || false

    repo = PaymentMethodsRepository.new
    rec = repo.create(owner_type: owner_type, owner_id: owner_id, method_type: method_type, details: details, is_default: is_default)
    render json: rec, status: :created
  end
end
