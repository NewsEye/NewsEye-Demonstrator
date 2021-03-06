Rails.application.routes.draw do

  concern :range_searchable, BlacklightRangeLimit::Routes::RangeSearchable.new
  scope "(:locale)", locale: /en|fr|de|fi/ do
    devise_for :users
    post 'authenticate', to: 'api_authentication#authenticate'
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
      concerns :range_searchable

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
    # mount BlacklightAdvancedSearch::Engine => '/'
    # get 'advanced' => 'advanced#index'
    # get 'advanced/range_limit' => 'advanced#range_limit'


    get '/annotations/search', to: 'annotations#search'

    post '/annotations/add', to: 'annotations#add_annotation'

    get '/locales/:id/translation.json', to: 'assets#locale'

    get '/explore', to: 'catalog#explore'

    resources :feedbacks

    post '/investigate', to: 'investigator#investigate'

    root to: "catalog#index"
    # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

    resources :datasets

  end

  mount Riiif::Engine => '/iiif', as: 'riiif'

  get '/iiif/:id/manifest.json', to: 'iiif#manifest'
  get '/iiif/:id/annotated_manifest.json', to: 'iiif#manifest_with_annotations'
  get '/iiif/:id/list/:name', to: 'iiif#annotation_list'
  get '/iiif/:id/layer/:name', to: 'iiif#layer'

end
