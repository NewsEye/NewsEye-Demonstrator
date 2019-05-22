class DatasetsController < ApplicationController
  before_action :set_dataset, only: [:show, :edit, :update, :destroy, :delete_searches, :add_issue]

  # GET /datasets
  # GET /datasets.json
  def index
    @datasets = Dataset.all
  end

  # GET /datasets/1
  # GET /datasets/1.json
  def show
  end

  # GET /datasets/new
  def new
    @dataset = Dataset.new
  end

  # GET /datasets/1/edit
  def edit
  end

  # POST /datasets
  # POST /datasets.json
  def create
    dataset_params_copy = dataset_params
    dataset_params_copy[:searches] = [dataset_params[:searches]]
    @dataset = Dataset.create(dataset_params_copy)
    # @dataset.user_id = current_user.id
    # @dataset.searches.append(dataset_params[:search])
    respond_to do |format|
      if @dataset.save
        format.html { redirect_to @dataset, notice: 'Dataset was successfully created.' }
        format.json { render :show, status: :created, location: @dataset }
      else
        puts @dataset.errors.inspect
        format.html { render :new }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /datasets/1
  # PATCH/PUT /datasets/1.json
  def update
    dataset_params_copy = dataset_params
    if dataset_params_copy[:search_to_add]
      dataset_params_copy[:searches] = @dataset.searches + [dataset_params_copy[:search_to_add]]
      dataset_params_copy = dataset_params_copy.except(:search_to_add)
    end
    puts "### #{dataset_params_copy}"
    # dataset_params_copy[:searches] = [dataset_params[:searches]] + @dataset.searches
    # dataset_params_copy[:issues] = [dataset_params[:issues]] + @dataset.issues
    # dataset_params_copy[:articles] = [dataset_params[:articles]] + @dataset.articles
    respond_to do |format|
      if @dataset.update(dataset_params_copy)
        format.html { redirect_to request.referer, alert: 'Dataset was successfully updated.' }
        format.json { render :show, status: :ok, location: @dataset }
      else
        format.html { render :edit }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /datasets/1/delete_searches
  def delete_searches
    to_delete = dataset_params[:searches_to_remove]
    @dataset.searches -= to_delete
    @dataset.save
    respond_to do |format|
      format.html {redirect_to request.referer, alert: 'Dataset was successfully updated.'}
      format.json {redirect_to request.referer, alert: 'Dataset was successfully updated.'}
    end
  end

  # POST /datasets/1/add_issue
  def add_issue
    to_add = dataset_params[:issues]
    @dataset.issues.append(to_add) unless @dataset.issues.include? to_add
    @dataset.save
    respond_to do |format|
      format.html {redirect_to request.referer, alert: 'Dataset was successfully updated.'}
      format.json {redirect_to request.referer, alert: 'Dataset was successfully updated.'}
    end
  end

  # DELETE /datasets/1
  # DELETE /datasets/1.json
  def destroy
    @dataset.destroy
    respond_to do |format|
      format.html { redirect_to datasets_url, notice: 'Dataset was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_dataset
      @dataset = Dataset.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def dataset_params
      params.require(:dataset).permit(:title, :user_id, :searches, :articles, :issues, :search_to_add, searches_to_remove: [])

    end
end
