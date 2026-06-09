Rails.application.routes.draw do
  get '/api-docs/swagger.json', to: 'swagger#show', defaults: { format: :json }

  # Swagger/OpenAPI Documentation (only in development/test)
  if defined?(Rswag::Ui) && defined?(Rswag::Api)
    mount Rswag::Ui::Engine => '/api-docs'
    mount Rswag::Api::Engine => '/api-docs'
    get '/api-docs' => redirect('/api-docs/index.html')
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Auth (público — sem token)
  scope "/api/v1" do
    post "/auth/register", to: "auth#register"
    post "/auth/login",    to: "auth#login"
    post "/auth/logout",   to: "auth#logout"
    get  "/auth/me",       to: "auth#me"
    get  "/auth/me/contributor", to: "auth#me_contributor", as: :api_v1_auth_me_contributor
  end

  post "/auth/register", to: "auth#register"
  post "/auth/login",    to: "auth#login"
  post "/auth/logout",   to: "auth#logout"
  get  "/auth/me",       to: "auth#me"
  get  "/auth/me/contributor", to: "auth#me_contributor"

  get "/associations", to: "associations#index"
  post "/associations", to: "associations#create"
  delete "/associations/:organization_id", to: "associations#destroy"

  get "/me/recurring_donations", to: "my_recurring_donations#index"
  post "/me/recurring_donations", to: "my_recurring_donations#create"
  delete "/me/recurring_donations/:id", to: "my_recurring_donations#destroy"

  get "up" => "rails/health#show", as: :rails_health_check
  get "health/cassandra" => "health#cassandra", as: :cassandra_health_check
  get "health/redis" => "health#redis", as: :redis_health_check
  get "health/all" => "health#all", as: :health_all

  scope "/api/v1" do
    get "/public/organizations", to: "public_organizations#index", as: :api_v1_public_organizations
    post "/public/checkout", to: "checkout#create", as: :api_v1_public_checkout
    post "/public/donate/:organization_id", to: "public_donations#create", as: :api_v1_public_donate
    get "/public/campaigns", to: "public_campaigns#index", as: :api_v1_public_campaigns
    get "/public/campaigns/:campaign_id/accountability", to: "public_accountability#show", as: :api_v1_public_accountability
    get "/public/institutions/:id", to: "public_institutions#show", as: :api_v1_public_institution

    get "/associations", to: "associations#index", as: :api_v1_associations
    post "/associations", to: "associations#create"
    delete "/associations/:organization_id", to: "associations#destroy", as: :api_v1_association

    get "/me/recurring_donations", to: "my_recurring_donations#index", as: :api_v1_my_recurring_donations
    post "/me/recurring_donations", to: "my_recurring_donations#create"
    delete "/me/recurring_donations/:id", to: "my_recurring_donations#destroy", as: :api_v1_my_recurring_donation

    resources :organizations, only: [ :create, :show, :index ] do
      resources :expenses, controller: "organization_expenses"
      resources :campaigns, only: [ :create, :show, :index, :update ] do
        member do
          put :redeem
        end
        resources :expenses, controller: "expenses" do
          resources :attachments, only: [:create, :destroy], controller: "expense_attachments" do
            get :download, on: :member
          end
        end
      end
    end
    resources :contributors, only: [ :show, :index ] do
      resources :recurring_donations, only: [ :create, :index, :update, :destroy ], controller: "recurring_donations"
    end
    resources :memberships, only: [ :create, :index ]
    get "/owners/:owner_type/:owner_id/wallet", to: "wallets#show", as: :api_v1_owner_wallet
    post "/owners/:owner_type/:owner_id/transactions", to: "transactions#create", as: :api_v1_owner_transactions
    get "/owners/:owner_type/:owner_id/transactions", to: "transactions#index", as: :api_v1_owner_transactions_index
    get "/owners/:owner_type/:owner_id/transactions/:id", to: "transactions#show", as: :api_v1_owner_transaction
    get "/campaigns/:campaign_id/transactions", to: "transactions#by_campaign", as: :api_v1_campaign_transactions
    get  "/owners/:owner_type/:owner_id/payment_methods", to: "payment_methods#index", as: :api_v1_owner_payment_methods_index
    post "/owners/:owner_type/:owner_id/payment_methods", to: "payment_methods#create", as: :api_v1_owner_payment_methods
    delete "/owners/:owner_type/:owner_id/payment_methods/:id", to: "payment_methods#destroy", as: :api_v1_owner_payment_method_delete
    get "/finance/:owner_type/:owner_id", to: "finance#show", as: :api_v1_finance
    get "/organizations/:id/dashboard", to: "dashboard#show", as: :api_v1_org_dashboard
    get "/recurring_donations", to: "recurring_donations#index", as: :api_v1_recurring_donations
    post "/recurring_donations", to: "recurring_donations#create", as: :api_v1_create_recurring_donation
    delete "/recurring_donations/:id", to: "recurring_donations#destroy", as: :api_v1_delete_recurring_donation
    resources :credit_lines, only: [:index, :show, :create] do
      post "use", on: :member
    end
    get "/credit_lines/:organization_id/request/:amount_cents", to: "credit_lines#request_credit", as: :api_v1_credit_request
    get "/credit_lines/:organization_id/bills", to: "credit_lines#bills", as: :api_v1_credit_bills
    post "/credit_lines/:organization_id/bills/:id/pay", to: "credit_lines#pay_bill", as: :api_v1_credit_pay_bill
    resources :organizations, only: [] do
      resources :posts, controller: "org_posts", only: [:index, :create, :destroy]
    end
    resources :posts, only: [] do
      resources :comments, controller: "post_comments", only: [:index, :create, :destroy]
    end
    get "/public/organizations/:organization_id/posts/:post_id/attachments/:attachment_id/download", to: "post_attachments#download", as: :api_v1_public_post_attachment_download
  end

  resources :organizations, only: [ :create, :show, :index ] do
    resources :expenses, controller: "organization_expenses"
    resources :campaigns, only: [ :create, :show, :index, :update ] do
      member do
        put :redeem
      end
      resources :expenses, controller: "expenses" do
        resources :attachments, only: [:create, :destroy], controller: "expense_attachments" do
          get :download, on: :member
        end
      end
    end
  end
  resources :contributors, only: [ :show, :index ] do
    resources :recurring_donations, only: [ :create, :index, :update, :destroy ], controller: "recurring_donations"
  end
  resources :memberships, only: [ :create, :index ]
  get "/owners/:owner_type/:owner_id/wallet", to: "wallets#show", as: :owner_wallet
  post "/owners/:owner_type/:owner_id/transactions", to: "transactions#create", as: :owner_transactions
  get "/owners/:owner_type/:owner_id/transactions", to: "transactions#index", as: :owner_transactions_index
  get "/owners/:owner_type/:owner_id/transactions/:id", to: "transactions#show", as: :owner_transaction
  get "/campaigns/:campaign_id/transactions", to: "transactions#by_campaign", as: :campaign_transactions
  post "/owners/:owner_type/:owner_id/payment_methods", to: "payment_methods#create", as: :owner_payment_methods
  get  "/owners/:owner_type/:owner_id/payment_methods", to: "payment_methods#index", as: :owner_payment_methods_index
  delete "/owners/:owner_type/:owner_id/payment_methods/:id", to: "payment_methods#destroy", as: :owner_payment_method_delete
  get "/finance/:owner_type/:owner_id", to: "finance#show", as: :finance
  get "/organizations/:id/dashboard", to: "dashboard#show", as: :org_dashboard
  resources :credit_lines, only: [:index, :show, :create] do
    post "use", on: :member
  end

  resources :organizations, only: [] do
    resources :posts, controller: "org_posts", only: [:index, :create, :destroy]
  end
  resources :posts, only: [] do
    resources :comments, controller: "post_comments", only: [:index, :create, :destroy]
  end
  get "/public/organizations/:organization_id/posts/:post_id/attachments/:attachment_id/download", to: "post_attachments#download", as: :public_post_attachment_download
end
