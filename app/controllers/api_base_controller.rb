class ApiBaseController < ApplicationController
  protect_from_forgery with: :null_session, if: :json_request
  before_action :authenticate_request, if: :json_request
  before_action :authenticate_pra, only: [:list_datasets, :get_dataset_content]

  attr_reader :current_user

  def list_datasets
    datasets = User.find_by_email(params[:email]).datasets
    render json: datasets.map{|dts| [dts.title, dts.documents.hash] }
  end

  def get_dataset_content
    dataset = Dataset.where("user_id=#{User.find_by_email(params[:email]).id} AND title='#{params[:dataset_name]}'").first
    if dataset.nil?
        render json: {error: "Cannot find dataset."}
    else
        docs = dataset.documents
        docs.map! do |doc|
            if doc['type'] == "compound"
                doc['parts'] = CompoundArticle.find(doc['id']).parts
                return doc
            else
                return doc
            end
        end
        render json: docs
    end
  end

  private

  def authenticate_pra
    render json: { error: 'Not Authorized' }, status: 401 unless @current_user.email == "pra@newseye.eu"
  end

  def authenticate_request
    @current_user = AuthorizeApiRequest.call(request.headers).result
    render json: { error: 'Not Authorized' }, status: 401 unless @current_user
  end
end