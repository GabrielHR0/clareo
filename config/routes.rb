Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get "up" => "rails/health#show", as: :rails_health_check
  get "health/cassandra" => "health#cassandra", as: :cassandra_health_check
  resources :organizations, only: [ :create, :show, :index ]
  resources :contributors, only: [ :create, :show, :index ]
  resources :memberships, only: [ :create, :index ]
  get "/owners/:owner_type/:owner_id/wallet", to: "wallets#show", as: :owner_wallet
  post "/owners/:owner_type/:owner_id/transactions", to: "transactions#create", as: :owner_transactions
  post "/owners/:owner_type/:owner_id/payment_methods", to: "payment_methods#create", as: :owner_payment_methods
  resources :credit_lines, only: [:index, :show, :create] do
    post "use", on: :member
  end
end
