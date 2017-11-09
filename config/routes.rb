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
      get  'index'
      get  'authorize'
      get  'callback'
      get  'fetch_folders'
      get  'fetch_content'
      post 'create_sources'
    end
  end

  resources :sharepoint, only: [] do
    collection do
      get  'authorize'
      get  'callback'
      get  'fetch_folders'
      post 'create_sources'
    end
  end

  match '/auth/:provider/callback', to: 'sharepoint#callback', via: %i[get post]

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
