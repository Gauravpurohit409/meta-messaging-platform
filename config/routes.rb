Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  root "pages#home"
  get "privacy", to: "pages#privacy"
  get "terms", to: "pages#terms"
  get "inbox", to: "inbox#index", as: :inbox
  get "data_deletion/:code", to: "data_deletion#show", as: :data_deletion_status
  get "dashboard", to: "dashboard#show", as: :dashboard

  resources :templates do
    member do
      post :submit
      post :duplicate
    end
  end

  resources :campaigns, only: %i[index new create show destroy] do
    collection do
      get :sample
    end
    member do
      post :launch
      post :cancel
    end
  end

  resource :settings, only: %i[show update] do
    post :embedded_signup, action: :connect
    delete :embedded_signup, action: :disconnect
  end

  namespace :webhooks do
    get "meta", to: "meta#verify", as: :meta
    post "meta", to: "meta#receive"
    post "data_deletion", to: "data_deletion#create"
  end

  get "up" => "rails/health#show", as: :rails_health_check

  if Rails.env.development?
    require "sidekiq/web"
    authenticate :user do
      mount Sidekiq::Web => "/sidekiq"
    end
  end
end
