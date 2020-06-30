Rails.application.routes.draw do
  resources :dashboards
  resources :sends
  resources :mail_templates do
    member do
      get :send_email
    end
  end
  
  root 'dashboards#index'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
