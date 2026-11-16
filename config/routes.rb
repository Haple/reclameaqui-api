Rails.application.routes.draw do
  root "pages#home"

  # The API, laid out like SerpApi's: /search.json runs a search and
  # /searches/:id.json reads one back from the archive.
  get "search" => "searches#run", as: :search, defaults: { format: :json }
  get "searches/:id" => "searches#show", as: :archived_search, defaults: { format: :json }
  get "searches/:id/preview" => "searches#preview", as: :search_preview

  get "playground" => "playground#show"
  get "docs(/:engine)" => "docs#show", as: :docs
  get "blog/:slug" => "posts#show", as: :post

  # The playground and the live API are for guests, who sign in with a link
  # sent by email.
  get "sign_in" => "sessions#new", as: :sign_in
  post "sign_in" => "sessions#create"
  get "sign_in/sent" => "sessions#sent", as: :sign_in_sent
  get "sign_in/link" => "sign_in_links#show", as: :sign_in_link
  post "sign_in/link" => "sign_in_links#create"
  delete "sign_out" => "sessions#destroy", as: :sign_out
  get "admin" => "admin#show", as: :admin

  get "up" => "rails/health#show", as: :rails_health_check
end
