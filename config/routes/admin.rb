namespace :admin do
  resources :users, constraints: { id: /[a-zA-Z.\/0-9_\-]+/ } do
    resources :keys, only: [:show, :destroy]
    resources :identities, except: [:show]
    resources :impersonation_tokens, only: [:index, :create] do
      member do
        put :revoke
      end
    end

    member do
      get :projects
      get :keys
      put :block
      put :unblock
      put :unlock
      put :confirm
      post :impersonate
      patch :disable_two_factor
      delete 'remove/:email_id', action: 'remove_email', as: 'remove_email'
    end
  end

  ## EE-specific
  resource :push_rule, only: [:show, :update]
  ## EE-specific

  resource :impersonation, only: :destroy

  resources :abuse_reports, only: [:index, :destroy]
  resources :spam_logs, only: [:index, :destroy] do
    member do
      post :mark_as_ham
    end
  end

  resources :applications

  resources :groups, only: [:index, :new, :create]

  scope(path: 'groups/*id',
        controller: :groups,
        constraints: { id: Gitlab::PathRegex.full_namespace_route_regex, format: /(html|json|atom)/ }) do

    scope(as: :group) do
      put :members_update
      get :edit, action: :edit
      get '/', action: :show
      patch '/', action: :update
      put '/', action: :update
      delete '/', action: :destroy
    end
  end

  resources :deploy_keys, only: [:index, :new, :create, :edit, :update, :destroy]

  resources :hooks, only: [:index, :create, :edit, :update, :destroy] do
    member do
      get :test
    end

    resources :hook_logs, only: [:show] do
      member do
        get :retry
      end
    end
  end

  resources :broadcast_messages, only: [:index, :edit, :create, :update, :destroy] do
    post :preview, on: :collection
  end

  resource :logs, only: [:show]
  resource :health_check, controller: 'health_check', only: [:show]
  resource :background_jobs, controller: 'background_jobs', only: [:show]

  ## EE-specific
  resource :email, only: [:show, :create]
  resources :audit_logs, controller: 'audit_logs', only: [:index]
  ## EE-specific

  resource :system_info, controller: 'system_info', only: [:show]
  resources :requests_profiles, only: [:index, :show], param: :name, constraints: { name: /.+\.html/ }

  get 'conversational_development_index' => 'conversational_development_index#show'

  resources :projects, only: [:index]

  scope(path: 'projects/*namespace_id',
        as: :namespace,
        constraints: { namespace_id: Gitlab::PathRegex.full_namespace_route_regex }) do
    resources(:projects,
              path: '/',
              constraints: { id: Gitlab::PathRegex.project_route_regex },
              only: [:show]) do

      member do
        put :transfer
        post :repository_check
      end

      resources :runner_projects, only: [:create, :destroy]
    end
  end

  resource :appearances, only: [:show, :create, :update], path: 'appearance' do
    member do
      get :preview
      delete :logo
      delete :header_logos
    end
  end

  resource :application_settings, only: [:show, :update] do
    resources :services, only: [:index, :edit, :update]

    get :usage_data
    put :reset_runners_token
    put :reset_health_check_token
    put :clear_repository_check_states
  end

  ## EE-specific
  resource :license, only: [:show, :new, :create, :destroy] do
    get :download, on: :member
  end

  resources :geo_nodes, only: [:index, :create, :destroy] do
    member do
      post :repair
      post :toggle
      get  :status
    end
  end
  ## EE-specific

  resources :labels

  resources :runners, only: [:index, :show, :update, :destroy] do
    member do
      get :resume
      get :pause
    end
  end

  resources :cohorts, only: :index

  resources :jobs, only: :index do
    collection do
      post :cancel_all
    end
  end

  root to: 'dashboard#index'
end
