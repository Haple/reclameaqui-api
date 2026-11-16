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

  get "up" => "rails/health#show", as: :rails_health_check
end
