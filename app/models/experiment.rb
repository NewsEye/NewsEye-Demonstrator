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

    def run
        tools_to_start = self.description.select { |e| e['group'] == 'nodes' and e['data']['class'] == 'analysis_tool' and e['data']['task_status'] == 'not started' }
        tools_to_start.each do |tool|
            tool_inputs = tool['data']['inputs']
            if tool_inputs.size == 1
                tool_input = self.description.select { |e| e['group'] == 'nodes' }.find { |e| e['data']['id'] == tool_inputs[0] }
                if tool_input
                    if tool_input['data']['type'] == "dataset"
                        dataset = Dataset.find tool_input['data']['params']['source_id']
                        username = User.find(dataset.user_id).email
                        api_response = PersonalResearchAssistantService.run_tool dataset.title, username, tool['data']['type'], tool['data']['parameters']
                        if api_response['uuid']
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
                            puts "Error creating task"
                        end
                    end
                end
            end
        end
        tools_to_update = self.description.select { |e| e['group'] == 'nodes' and e['data']['class'] == 'analysis_tool' and e['data']['task_status'] == 'running' }
        tools_to_update.each do |tool|
            t = Task.where("uuid = '#{tool['data']['task_uuid']}'")[0]
            api_response = PersonalResearchAssistantService.get_analysis_task t.uuid
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
        end
    end

    def self.process_pra_output(data)
        nodes = []
        edges = []
        for collec in data['collections']
            node = {
                id: "collection_#{collec['collection_no']}",
                type: 'dataset',
                output_type: "dataset",
                inputs: [],
                params: {
                    source: collec['collection_type'],
                    source_name: collec["search_query"]['q'],
                    search_query: collec["search_query"]
                }
            }
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
            node[:class] = "analysis_tool" if node[:type] != "SplitByFacet"
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
            next if node[:data][:type] != "dataset"
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
