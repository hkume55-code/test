Rails.application.routes.draw do
  resources :dashboards
  resources :sends
  resources :mail_templates do
    member do
      get :send_email
    end
  end

  get('cc/:customer_id/:clickcount_project_id/:clickcount_id/:person_id/:sig', :controller => :cc, :action => :clickcount_request, :as => 'clickcount_request_cc')
  
  root 'dashboards#index'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
