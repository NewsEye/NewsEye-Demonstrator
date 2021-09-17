class ExperimentController < ApplicationController

    before_action :authenticate_user!

    def index
    end

    def create
        experiment = Experiment.new
        experiment.user = current_user
        experiment.title = params[:title]
        begin
            experiment.save!
            render json: {status: 'ok'}
        rescue ActiveRecord::RecordNotUnique
            render json: {status: "error", message: "An experiment with this title already exists."}
        rescue ActiveRecord::RecordInvalid
            render json: {status: "error", message: "The title should not be blank."}
        end
    end

    def show
        @experiment = Experiment.find params[:id]
        @tools = @experiment.load_tools
        @tools_description = File.read("#{Rails.root}/lib/newspapers_tools.json")
    end

    def update_experiments_list
        respond_to do |format|
            format.js
        end
    end

    def add_tool
        @experiment = Experiment.find(params[:id])
        tool_params = JSON.parse params[:tool]
        tool = Tool.new
        tool.tool_type = tool_params['type']
        tool.input_type = tool_params['input_type']
        tool.output_type = tool_params['output_type']
        tool.parameters = tool_params['parameters']
        tool.status = "created"
        tool.experiment = @experiment
        tool.save!
        @experiment.add_tool(params[:parent_id].to_i, tool)
        @experiment.save!
        render 'experiment/update_experiment_area'
    end

    def delete_tool
        @experiment = Experiment.find(params[:id])
        tools_to_destroy_ids = @experiment.delete_tool(params[:tool_id].to_i)
        @experiment.save!
        Tool.destroy(tools_to_destroy_ids)
        render 'experiment/update_experiment_area'
    end

    def edit_tool_form
        @tool = Tool.find(params[:tool_id])
        render partial: 'tool/parameters', locals: {tool: @tool}
    end

    def edit_tool
        @experiment = Experiment.find(params[:id])
        @tool = Tool.find(params[:tool_id])
        modified = false
        @tool.parameters.map! do |param|
            if param['value'] != params[:parameters][param['name']]
                modified = true
            end
            param['value'] = params[:parameters][param['name']]
            param
        end
        @tool.status = "configured" if modified
        @tool.save!
        render 'experiment/update_experiment_area'
    end

    def run_tool
        @experiment = Experiment.find(params[:id])
        @tool = Tool.find(params[:tool_id])
        @tool.run()
        render 'experiment/update_experiment_area'
    end

    def run_experiment

    end
end
