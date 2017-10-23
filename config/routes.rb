require 'sidekiq/web'
Rails.application.routes.draw do
  mount Sidekiq::Web => '/sidekiq_worker'
  resources :dropbox, only: [] do
    collection do
      get  'authorize'
      get  'callback'
      get  'fetch_folders'
      post 'create_sources'
    end
  end

  resources :google_team_drive, only: [] do
    collection do
      get  'authorize'
      get  'callback'
      get  'fetch_folders'
      post 'create_sources'
    end
  end

  namespace :api do
    namespace :v1 do
      resources :source_types, only: [] do
        member do
          post 'fetch_content'
        end
      end

      resources :sources, only: [] do
        member do
          post 'fetch_content'
        end
      end

      resources :webhook, only: [] do
        collection do
          post 'fetch_content'
        end
      end
    end
  end
end
