require 'sidekiq/web'
require 'sidekiq/cron/web'

Rails.application.routes.draw do
  concern :access_requestable do
    post :request_access, on: :collection
    post :approve_access_request, on: :member
  end

  concern :awardable do
    post :toggle_award_emoji, on: :member
  end

  draw :sherlock
  draw :development
  draw :ci

  use_doorkeeper do
    controllers applications: 'oauth/applications',
                authorized_applications: 'oauth/authorized_applications',
                authorizations: 'oauth/authorizations'
  end

  namespace :oauth do
    scope path: 'geo', controller: :geo_auth, as: :geo do
      get 'auth'
      get 'callback'
      get 'logout'
    end
  end

  use_doorkeeper_openid_connect

  # Autocomplete
  get '/autocomplete/users' => 'autocomplete#users'
  get '/autocomplete/users/:id' => 'autocomplete#user'
  get '/autocomplete/projects' => 'autocomplete#projects'
  get '/autocomplete/project_groups' => 'autocomplete#project_groups'

  # Search
  get 'search' => 'search#show'
  get 'search/autocomplete' => 'search#autocomplete', as: :search_autocomplete

  # JSON Web Token
  get 'jwt/auth' => 'jwt#auth'

  # Health check
  get 'health_check(/:checks)' => 'health_check#index', as: :health_check

  scope path: '-', controller: 'health' do
    get :liveness
    get :readiness
    get :metrics
  end

  # Koding route
  get 'koding' => 'koding#index'

  draw :api
  draw :sidekiq
  draw :help
  draw :snippets

  # Invites
  resources :invites, only: [:show], constraints: { id: /[A-Za-z0-9_-]+/ } do
    member do
      post :accept
      match :decline, via: [:get, :post]
    end
  end

  resources :sent_notifications, only: [], constraints: { id: /\h{32}/ } do
    member do
      get :unsubscribe
    end
  end

  # Spam reports
  resources :abuse_reports, only: [:new, :create]

  # Notification settings
  resources :notification_settings, only: [:create, :update]

  draw :import
  draw :uploads
  draw :explore
  draw :admin
  draw :profile
  draw :dashboard
  draw :group
  draw :user
  draw :project

  root to: "root#index"

  draw :test if Rails.env.test?

  get '*unmatched_route', to: 'application#route_not_found'
end
