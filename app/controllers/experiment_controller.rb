class ExperimentController < ApplicationController

    def show
        @experiment = Experiment.find params[:id]
        @tools = PersonalResearchAssistantService.list_utilities
        if current_user != @experiment.user
            respond_to do |format|
                format.html { redirect_to "/#{I18n.locale}/personal_workspace", notice: 'You do not have the right to access this experiment.' }
            end
        end
        respond_to do |format|
            format.html
        end
    end

    def add_data_source_modal
        @experiment_id = params[:experiment_id]
        respond_to do |format|
            format.js
        end
    end

    def explain_modal
        @content = JSON.parse PersonalResearchAssistantService.explain params[:task_uuid]
        respond_to do |format|
            format.js
        end
    end

    def report_modal
        @content = PersonalResearchAssistantService.get_experiment_report params[:task_uuid]
        puts @content
        respond_to do |format|
            format.js
        end
    end

    def add_data_source
        respond_to do |format|
            format.html { redirect_to "/#{I18n.locale}/experiment/#{params[:experiment_id]}", notice: 'Topic modelling query task was successfully created.' }
        end
    end

    def add_output_modal
        @node_type = params[:node_type]
        respond_to do |format|
            format.js
        end
    end

    def run_experiment
        @experiment = Experiment.find params[:experiment_id]
        @experiment.run
        @experiment.save
        respond_to do |format|
            format.js
        end
    end

    def new_experiment
        @experiment = Experiment.new
        @experiment.title = params[:title]
        @experiment.user = current_user
        @experiment.description = []
        @experiment.save
        respond_to do |format|
            format.js
        end
    end

    def save
        @experiment = Experiment.find params[:experiment_id]
        @experiment.description = JSON.parse params[:elements]
        @experiment.save
        render json: 'ok'
    end

    def load
        @experiment = Experiment.find params[:experiment_id]
        render json: @experiment.description
    end

    def get_run_id
        experiment = Experiment.find params[:experiment_id]
        if experiment.task
            render json: [experiment.task.uuid]
        else
            render json: []
        end
        # render json: experiment.task.uuid
    end

end