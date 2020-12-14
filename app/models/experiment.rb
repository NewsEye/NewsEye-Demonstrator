class Experiment < ActiveRecord::Base

    belongs_to :user, optional: false
    belongs_to :task, optional: true

    def get_status
        if self.task.nil?
            ""
        else
            self.task.status
        end
    end

    def get_owner
        if self.task
            "PRA"
        else
            "User"
        end
    end

    def get_nb_processors
        return 0 if self.description.nil?
        self.description.select{ |t| t['group'] == 'nodes' and t['data']['class'] == "analysis_tool" }.size
    end

    def get_nb_processors_finished
        return 0 if self.description.nil?
        self.description.select{ |t| t['group'] == 'nodes' and t['data']['class'] == "analysis_tool" and t['data']['task_status'] == "finished" }.size
    end

    def run
        tools_to_update = self.description.select { |e| e['group'] == 'nodes' and e['data']['class'] == 'analysis_tool' and e['data']['task_status'] == 'running' }
        tools_to_update.each do |tool|
            t = Task.where("uuid = '#{tool['data']['task_uuid']}'")[0]
            api_response = PersonalResearchAssistantService.get_analysis_task t.uuid
            if api_response && api_response['uuid']
                t.update(status: api_response['task_status'], uuid: api_response['uuid'],
                         started: api_response['task_started'], finished: api_response['task_finished'],
                         task_type: api_response['task_type'], parameters: api_response['task_parameters'],
                         results: api_response['task_result']) unless api_response.nil?
                self.description.map! do |node|
                    if node['data']['id'] == tool['data']['id']
                        node['data']["task_uuid"] = api_response['uuid']
                        node['data']["task_status"] = api_response['task_status']
                        node['data']["task_result"] = api_response['task_result']
                        node
                    else
                        node
                    end
                end
            else
                puts "Error updating task : #{api_response}"
            end
        end

        tools_to_start = self.description.select { |e| e['group'] == 'nodes' and e['data']['class'] == 'analysis_tool' and e['data']['task_status'] != 'running' and e['data']['task_status'] != 'finished' }
        tools_to_start.each do |tool|
            tool_inputs = tool['data']['inputs']
            if tool_inputs.size == 1 # only one input, another case for comparison
                tool_input = self.description.select { |e| e['group'] == 'nodes' }.find { |e| e['data']['id'] == tool_inputs[0] }
                if tool_input
                    if tool_input['data']['type'] == "dataset"
                        dataset = Dataset.find tool_input['data']['params']['source_id']
                        username = User.find(dataset.user_id).email
                        api_response = PersonalResearchAssistantService.run_tool_dataset dataset.title, username, tool['data']['type'], tool['data']['parameters']
                    elsif tool_input['data']['type'] == "search"
                        api_response = PersonalResearchAssistantService.run_tool_search tool_input['data']['params']['query_params'], tool['data']['type'], tool['data']['parameters']
                    elsif tool_input['data']['class'] == 'analysis_tool'
                        api_response = PersonalResearchAssistantService.run_tool_analysis [tool_input['data']['task_uuid']], tool['data']['type'], tool['data']['parameters']
                    end
                    if api_response && api_response['uuid']
                        Task.create(user: self.user, status: api_response['task_status'], uuid: api_response['uuid'],
                                    started: api_response['task_started'], finished: api_response['task_finished'],
                                    task_type: api_response['task_type'], parameters: api_response['task_parameters'],
                                    results: api_response['task_result'])
                        self.description.map! do |node|
                            if node['data']['id'] == tool['data']['id']
                                node['data']["task_uuid"] = api_response['uuid']
                                node['data']["task_status"] = api_response['task_status']
                                node['data']["task_result"] = api_response['task_result']
                                node
                            else
                                node
                            end
                        end
                    else
                        puts "Error creating task : #{api_response}"
                    end
                end
            else # when multiple inputs

            end
        end
        self.save!
        # process finished split nodes
        to_add = {}
        splitters = self.description.select { |e| e['group'] == 'nodes' and e['data']['type'] == 'SplitByFacet' and e['data']['task_status'] == 'finished' }
        puts splitters
        splitters.each do |splitter|
            split_id = splitter['data']['id']
            to_add[split_id] = {}
            edges_from_splitter = self.description.select { |e| e['group'] == 'edges' and e['data']['source'] == splitter['data']['id'] }
            split_outputs = edges_from_splitter.map { |edge| self.description.select { |e| e['data']['id'] == edge['data']['target'] } }
            if split_outputs.empty?
                origin_node = self.description.select { |e| e['group'] == 'nodes' and e['data']['id'] == splitter['data']['inputs'][0] }[0]
                splitter['data']['task_result']['result'].each do |facet_value, query_params|
                    to_add[split_id][facet_value] = {}
                    if origin_node['data']['type'] == "search"
                        to_add[split_id]["type"] = "search"
                        to_add[split_id][facet_value]["query_params"] = query_params
                        to_add[split_id][facet_value]["search_url"] = ApplicationController.helpers.search_url_from_solr_params query_params
                    elsif origin_node['data']['type'] == "dataset"
                        to_add[split_id]["type"] = "dataset"
                        doclist = query_params["fq"].select { |e| e.start_with? "{!terms f=id}" }[0]
                        doclist = doclist["{!terms f=id}".size..-1].split(',')
                        to_add[split_id][facet_value]["doclist"] = doclist
                    end
                end
            end
        end
        to_add
    end

    def self.process_pra_output(data, current_user, experiment)
        nodes = []
        edges = []
        root_is_a_dataset = data['collections'].select{|collec| collec["origin"].include? "root"}[0]["collection_type"] == "dataset"
        for collec in data['collections']
            if collec["collection_type"] == "dataset" or root_is_a_dataset # hack to be removed eventually
                node = {
                    id: "collection_#{collec['collection_no']}",
                    type: 'dataset',
                    output_type: "dataset",
                    inputs: [],
                    params: {
                        source: "dataset",
                        source_id: current_user.datasets.where(title: data["dataset"])[0].id,
                        source_name: data["dataset"]
                    }
                }
            elsif collec["collection_type"] == "search_query"
                if collec["origin"] == "root"
                    search = experiment.task.search
                    node = {
                        id: "collection_#{collec['collection_no']}",
                        type: 'search',
                        output_type: "dataset",
                        inputs: [],
                        params: {
                            source: "search",
                            source_id: search.id,
                            source_name: search.description,
                            query_params: search.query,
                            search_url: search.query_url
                        }
                    }
                else
                    node = {
                        id: "collection_#{collec['collection_no']}",
                        type: 'search',
                        output_type: "dataset",
                        inputs: [],
                        params: {
                            source: "search",
                            query_params: collec["search_query"],
                            search_url: ApplicationController.helpers.search_url_from_solr_params(collec["search_query"])
                        }
                    }
                end
            end
            for origin in collec['origin']
                node[:inputs] << origin if origin != "root"
            end
            nodes << {group: "nodes", data: node}
        end

        for res in data['result']
            node = {
                id: res['uuid'],
                type: res['processor'],
                task_status: res['task_status'],
                parameters: res['parameters']
            }
            if node[:type] == "Comparison"
                node[:inputs] = res['parents']
            else
                node[:inputs] = res['collections'].map { |colid| "collection_#{colid}" }
            end
            node[:class] = "analysis_tool" #if node[:type] != "SplitByFacet"
            nodes << {group: "nodes", data: node}
            for input in node[:inputs]
                edge = {
                    id: "edge_#{edges.size}",
                    source: input,
                    target: node[:id]
                }
                edges << {group: "edges", data: edge}
            end
        end

        for node in nodes
            # next if node[:data][:type] != "dataset"
            for input in node[:data][:inputs]
                edge = {
                    id: "edge_#{edges.size}",
                    source: input,
                    target: node[:data][:id]
                }
                edges << {group: "edges", data: edge}
            end
        end

        elements = edges + nodes
    end

end
