Rails.application.routes.draw do
  # get 'job_posts/feed'
  get 'feed' => 'job_posts#feed' #, format: 'atom'
  get 'job_postings' => 'job_posts#job_postings', :q => /.*/ #, format: 'atom'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
