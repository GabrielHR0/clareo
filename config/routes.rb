Rails.application.routes.draw do
  get '/api-docs/swagger.json', to: 'swagger#show', defaults: { format: :json }

  # Swagger/OpenAPI Documentation
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  get '/api-docs' => redirect('/api-docs/index.html')

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Auth (público — sem token)
  scope "/api/v1" do
    post "/auth/register", to: "auth#register"
    post "/auth/login",    to: "auth#login"
    get  "/auth/me",       to: "auth#me"
  end

  post "/auth/register", to: "auth#register"
  post "/auth/login",    to: "auth#login"
  get  "/auth/me",       to: "auth#me"

  get "up" => "rails/health#show", as: :rails_health_check
  get "health/cassandra" => "health#cassandra", as: :cassandra_health_check
  get "health/redis" => "health#redis", as: :redis_health_check
  get "health/all" => "health#all", as: :health_all

  scope "/api/v1" do
    post "/public/checkout", to: "checkout#create", as: :api_v1_public_checkout
    post "/public/donate/:organization_id", to: "public_donations#create", as: :api_v1_public_donate
    get "/public/campaigns/:campaign_id/accountability", to: "public_accountability#show", as: :api_v1_public_accountability
    resources :organizations, only: [ :create, :show, :index ] do
      resources :campaigns, only: [ :create, :show, :index ] do
        resources :expenses, controller: "expenses" do
          resources :attachments, only: [:create, :destroy], controller: "expense_attachments" do
            get :download, on: :member
          end
        end
      end
    end
    resources :contributors, only: [ :create, :show, :index ] do
      resources :recurring_donations, only: [ :create, :index, :update, :destroy ], controller: "recurring_donations"
    end
    resources :memberships, only: [ :create, :index ]
    get "/owners/:owner_type/:owner_id/wallet", to: "wallets#show", as: :api_v1_owner_wallet
    post "/owners/:owner_type/:owner_id/transactions", to: "transactions#create", as: :api_v1_owner_transactions
    get "/owners/:owner_type/:owner_id/transactions", to: "transactions#index", as: :api_v1_owner_transactions_index
    get "/owners/:owner_type/:owner_id/transactions/:id", to: "transactions#show", as: :api_v1_owner_transaction
    get "/campaigns/:campaign_id/transactions", to: "transactions#by_campaign", as: :api_v1_campaign_transactions
    post "/owners/:owner_type/:owner_id/payment_methods", to: "payment_methods#create", as: :api_v1_owner_payment_methods
    get "/organizations/:id/dashboard", to: "dashboard#show", as: :api_v1_org_dashboard
    resources :credit_lines, only: [:index, :show, :create] do
      post "use", on: :member
    end
  end

  resources :organizations, only: [ :create, :show, :index ] do
    resources :campaigns, only: [ :create, :show, :index ] do
      resources :expenses, controller: "expenses" do
        resources :attachments, only: [:create, :destroy], controller: "expense_attachments" do
          get :download, on: :member
        end
      end
    end
  end
  resources :contributors, only: [ :create, :show, :index ] do
    resources :recurring_donations, only: [ :create, :index, :update, :destroy ], controller: "recurring_donations"
  end
  resources :memberships, only: [ :create, :index ]
  get "/owners/:owner_type/:owner_id/wallet", to: "wallets#show", as: :owner_wallet
  post "/owners/:owner_type/:owner_id/transactions", to: "transactions#create", as: :owner_transactions
  get "/owners/:owner_type/:owner_id/transactions", to: "transactions#index", as: :owner_transactions_index
  get "/owners/:owner_type/:owner_id/transactions/:id", to: "transactions#show", as: :owner_transaction
  get "/campaigns/:campaign_id/transactions", to: "transactions#by_campaign", as: :campaign_transactions
  post "/owners/:owner_type/:owner_id/payment_methods", to: "payment_methods#create", as: :owner_payment_methods
  get "/organizations/:id/dashboard", to: "dashboard#show", as: :org_dashboard
  resources :credit_lines, only: [:index, :show, :create] do
    post "use", on: :member
  end
end
