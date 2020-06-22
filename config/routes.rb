Rails.application.routes.draw do
  resources :sends do
    member do
      post :send_email
    end
  end
  
  root 'sends#index'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
