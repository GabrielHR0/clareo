class SwaggerController < ApplicationController
  def show
    swagger_file = Rails.root.join('swagger', 'v1', 'swagger.json')
    send_file swagger_file, type: 'application/json', disposition: 'inline'
  end
end
