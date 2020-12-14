to_add = JSON.parse "<%= j @to_add.html_safe %>"
current_page_class.initGraph ()-> # to take into account changes made in experiment.rb/run
    for split of to_add
        node_type = to_add[split]['type']
        delete to_add[split]['type']
        for facet of to_add[split]
            node_id = "#{node_type}_data_source_" + current_page_class.getNextId("#{node_type}_data_source")
            current_page_class.cy.add {
                group: "nodes"
                data: {
                    id: node_id
                    type: node_type
                    output_type: "dataset"
                    inputs: [split]
                    params: to_add[split][facet]
                }
            }
            current_page_class.cy.add {
                group: "edges"
                data: {
                    id: "edge_#{current_page_class.getNextId("edge")}"
                    source: split
                    target: node_id
                }
            }
    current_page_class.refreshLayout()
    $("div#main-flashes div:first-child").empty()
    log = $('<div class="alert alert-success">Done !<a class="close" data-dismiss="alert" href="#">×</a></div>')
    $("div#main-flashes div:first-child").append(log)
    API.get_experiment_status <%= @experiment.id %>, (data)->
        $("#expe_status_nb_tasks").html("#{data.responseJSON['finished']}/#{data.responseJSON['total']}")