class PaymentMethodsController < ApplicationController
  def index
    owner_type = params[:owner_type]
    owner_id = params[:owner_id]
    methods = PaymentMethodsRepository.list(owner_type, owner_id)
    render json: methods
  end

  def create
    owner_type = params[:owner_type]
    owner_id = params[:owner_id]
    method_type = params[:method_type]
    details = params[:details]&.to_unsafe_h || {}
    is_default = params[:is_default] || false

    rec = PaymentMethodsRepository.create(owner_type: owner_type, owner_id: owner_id, method_type: method_type, details: details, is_default: is_default)
    render json: rec, status: :created
  end

  def destroy
    owner_type = params[:owner_type]
    owner_id = params[:owner_id]
    method_id = params[:id]
    PaymentMethodsRepository.delete(owner_type, owner_id, method_id)
    head :no_content
  end
end
