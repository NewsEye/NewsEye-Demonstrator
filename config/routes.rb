Rails.application.routes.draw do
  
  
  devise_for :users
  concern :exportable, Blacklight::Routes::Exportable.new

  resources :solr_documents, only: [:show], path: '/catalog', controller: 'catalog' do
    concerns :exportable
  end

  resources :bookmarks do
    concerns :exportable

    collection do
      delete 'clear'
    end
  end

    concern :searchable, Blacklight::Routes::Searchable.new

  resource :catalog, only: [:index], as: 'catalog', path: '/catalog', controller: 'catalog' do
    concerns :searchable
  end

  concern :exportable, Blacklight::Routes::Exportable.new

  resources :solr_documents, only: [:show], path: '/catalog', controller: 'catalog' do
    concerns :exportable
  end

  resources :bookmarks do
    concerns :exportable

    collection do
      delete 'clear'
    end
  end

  mount Blacklight::Engine => '/'

  mount Riiif::Engine => '/iiif', as: 'riiif'

  get '/iiif/:id/manifest.json', to: 'iiif#manifest'
  get '/iiif/:id/annotated_manifest.json', to: 'iiif#manifest_with_annotations'
  get '/iiif/:id/list/:name', to: 'iiif#annotation_list'
  get '/iiif/:id/layer/:name', to: 'iiif#layer'

  get '/annotations/search', to: 'annotations#search'

  get '/locales/:id/translation.json', to: 'assets#locale'

  get '/explore', to: 'catalog#explore'

  root to: "catalog#index"
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
