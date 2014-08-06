Myapp::Application.routes.draw do
  Sidekiq::Web.app_url = '/'
  mount Sidekiq::Web => '/sidekiq'
  get "work" => "work#index"
  get "work/email" => "work#email"
  get "work/post" => "work#delayed_post"
  get "work/long" => "work#long"
  get "work/crash" => "work#crash"
  get "work/bulk" => "work#bulk"
end
