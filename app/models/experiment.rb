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

  def self.process_pra_output(data)
    nodes = []
    edges = []
    for collec in data['collections']
      node = {
          id: "collection_#{collec['collection_no']}",
          type: "text_collection",
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
        node[:inputs] = res['collections'].map{|colid| "collection_#{colid}" }
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
      next if node[:data][:type] != "text_collection"
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
