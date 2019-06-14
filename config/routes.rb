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
    get '/update_tasks_status', to: 'investigator#update_status'

    root to: "catalog#index"
    # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

    resources :datasets

    post '/datasets/:id/delete_searches', to: 'datasets#delete_searches'
    post '/datasets/add', to: 'datasets#add'
    post '/datasets/create_and_add', to: 'datasets#create_and_add'
    post '/datasets/delete_elements', to: 'datasets#delete_elements'

    get '/personal_workspace', to: 'personal_workspace#index'
    get '/personal_workspace/show_report/:task_uuid', to: 'personal_workspace#show_report'
    get '/personal_workspace/show_params/:task_uuid', to: 'personal_workspace#show_params'
    get '/personal_workspace/describe_topics/', to: 'personal_workspace#describe_topics'
    get '/personal_workspace/list_models', to: 'personal_workspace#list_models'
    post '/personal_workspace/tm_action', to: 'personal_workspace#tm_action'
    post '/personal_workspace/analyse', to: 'personal_workspace#analysis_task'

  end

  mount Riiif::Engine => '/iiif', as: 'riiif'

  get '/iiif/:id/manifest.json', to: 'iiif#manifest'
  get '/iiif/:id/annotated_manifest.json', to: 'iiif#manifest_with_annotations'
  get '/iiif/:id/list/:name', to: 'iiif#annotation_list'
  get '/iiif/:id/layer/:name', to: 'iiif#layer'

end
