class PaymentMethodsController < ApplicationController
  def create
    owner_type = params[:owner_type]
    owner_id = params[:owner_id]
    method_type = params[:method_type]
    details = (params[:details] || {}).to_unsafe_h
    is_default = params[:is_default] || false

    rec = PaymentMethodsRepository.create(owner_type: owner_type, owner_id: owner_id, method_type: method_type, details: details, is_default: is_default)
    render json: rec, status: :created
  end
end
