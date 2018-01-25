require 'sidekiq/web'
Rails.application.routes.draw do
  mount Sidekiq::Web => '/sidekiq_worker'

  resources :edx, only: [] do
    collection do
      get 'index'
      get 'authorize'
      get 'callback'
      get 'catalogs'
      get 'courses'
    end
  end  

  namespace :api do
    namespace :v1 do
      resources :webhook, only: [] do
        collection do
          post 'fetch_content'
        end
      end
    end
  end
end
