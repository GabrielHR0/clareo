Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get "up" => "rails/health#show", as: :rails_health_check
  get "health/cassandra" => "health#cassandra", as: :cassandra_health_check
  resources :organizations, only: [ :create, :show, :index ]
  resources :contributors, only: [ :create, :show, :index ]
  resources :memberships, only: [ :create, :index ]
end
