Rails.application.routes.draw do
  root 'pages#home'

  resources :subscribers
  devise_for :users, :controllers => {:registrations => "registrations"}
  devise_scope :user do
    get 'start', to: "registrations#start", as: 'start'
    get 'signup', to: "registrations#new", as: 'signup'
    get 'login', to: "sessions#new", as: 'login'
    get 'settings', to: "registrations#edit", as: 'settings'
    delete 'logout', to: "sessions#destroy", as: 'logout'
  end

  get 'connect', to: "soundcloud#connect"
  get 'soundcloud/connected', to: "soundcloud#auth"

  # static
  get 'about', to: "pages#about", as: 'about'
end
