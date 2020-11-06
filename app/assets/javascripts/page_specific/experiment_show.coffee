class @ExperimentShow
    constructor: ->
        self = @
        console.log 'show'
        @experiment_id = new URL(window.location).pathname.split('/').slice(-1)[0]
        @initGraph()
        @controls()
        @modals()

    controls: ->
        self = @
        $("#delete_node_button").on "click", (event)->
            confirmed = confirm("Are you sure you want to delete this node and all its descendants ?")
            selected_node = self.cy.nodes(":selected")[0]
            if selected_node != undefined and confirmed
                self.cy.nodes(":selected").unselect()
                self.removeNode selected_node

        $("#node_parameters_button").on "click", (event)->
            selected_node = self.cy.$(':selected')[0]
            $("#modal-parameters").find(".modal-content").html self.create_parameters_modal(selected_node)
            $("#modal-parameters").modal()
            $('#modal-parameters')[0].classList.remove('hide')

        $("#run_update_button").on "click", (e)->
            $("div#main-flashes div:first-child").empty()
            log = $('<div class="alert alert-info">Running Experiment... (Can take some time)<a class="close" data-dismiss="alert" href="#">×</a></div>')
            $("div#main-flashes div:first-child").append(log)

        $("#node_results_button").on "click", (event)->
            selected_node = self.cy.$(':selected')[0]
            $("#modal-results").find(".modal-content").html PRAUtils.generate_results_modal(selected_node)
            $("#modal-results").modal()
            $('#modal-results')[0].classList.remove('hide')
            API.get_run_id_from_experiment_id self.experiment_id, (run_id)->
                if run_id.length != 0
                    API.query_task_results selected_node.data('id'), (data)->
                        canvases = PRAUtils.create_canvases(data)
                        $('#div_modal_results').html canvases
                        PRAUtils.populate_canvases data
                    API.task_report selected_node.data('id'), (data)->
                        $('#div_modal_report').html data.body[0]
                else
                    API.query_task_results selected_node.data('task_uuid'), (data)->
                        canvases = PRAUtils.create_canvases(data)
                        $('#div_modal_results').html canvases
                        PRAUtils.populate_canvases data
                    API.task_report selected_node.data('task_uuid'), (data)->
                        $('#div_modal_report').html data.body[0]

        $("#fit_view_button").on "click", (e)->
            self.cy.fit()


    modals: ->
        self = @
        $('#modal-add_data_source').on 'shown.bs.modal', (e)->
            $("#dataset_select_form_submit").on 'click', (event)->
                event.preventDefault()
                if $("#dataset_select option:selected").val() != ""
                    self.addNode {
                        id: "dataset_data_source_#{self.getNextId("dataset_data_source")}"
                        type: "dataset"
                        output_type: "dataset"
                        params: {
                            source: "dataset"
                            source_id: $("#dataset_select option:selected").val()
                            source_name:$("#dataset_select option:selected").text()
                        }
                        inputs: []
                    }
                    $('#modal-add_data_source').modal('hide')
                return false
        $("#modal-add_output").on "shown.bs.modal", (e)->
            tools = JSON.parse $("#pra_tools").data('tools')
            # in PRA: text_collection = dataset
            available_tools = tools.filter (tool)-> tool['input_type'] == self.cy.nodes(":selected").data("output_type")
            # HOTFIX because some analysis tool can be called directly on datasets (not indicated by API right now)
            other_tools = tools.filter (tool)-> tool['name'] == "SplitByFacet"
            if $("#node_type").text() == "dataset"
                Array::push.apply available_tools, other_tools
            for tool in available_tools
                tool_div = $("<div class=\"btn btn-primary\">#{tool['name']}</div>")
                tool_div.attr("data-outputtype", tool['output_type'])
                tool_div.attr("data-inputtype", tool['input_type'])
                tool_div.attr("data-tooltype", tool['name'])
                tool_div.addClass "active"
                tool_div.on "click", {tool: tool}, (e)->
                    $("#tools_grid .btn").removeClass "active"
                    $(e.target).addClass "active"
                    $("#tool_description").text(e.data.tool['description'])
                    $("#tool_parameters").html ""
                    for param in e.data.tool['parameters']
                        switch param['type']
                            when 'string'
                                container = $('<div class="input-group"></div>')
                                label = $('<span class="input-group-addon"></span>')
                                label.attr "title", param['description']
                                label.append document.createTextNode(param['name'])
                                input = $('<input class="form-control" type="text" placeholder="' + param['default'] + '"/>')
                                container.append label
                                container.append input
                                $("#tool_parameters").append container
                            else
                                console.log "default"
                $("#tools_grid").append tool_div
            $($("#tools_grid").children()[0]).trigger "click"
            $("#add_tool_button").on "click", (event)->
                tool_type = $("#tools_grid div.active").data('tooltype')
                added_node_id = "#{tool_type}_#{self.getNextId(tool_type)}"
                parameters = {}
                $("#tool_parameters > div").each (index)->
                    key = $(@).find("span").text()
                    val = if $(@).find("input").val() == "" then $(@).find("input").attr("placeholder") else $(@).find("input").val()
                    parameters[key] = val
                self.addNode {
                    id: added_node_id
                    type: tool_type
                    output_type: $("#tools_grid div.active").data('outputtype')
                    class: "analysis_tool"
                    inputs: [self.cy.nodes(":selected")[0].data('id')]
                    parameters: parameters
                    results: {}
                    task_status: "not started"
                }
                self.addEdge self.cy.nodes(":selected")[0].data('id'), added_node_id, {type: "final"}
                $('#modal-add_output').modal('hide')
                self.cy.$("##{added_node_id}").select()

    send_experiment_pra: ->
        @.cy.nodes().jsons().map(x => x.data)

    initGraph: ->
        self = @
        API.load_graph @experiment_id, (data)->
            self.cy = cytoscape({
                autoungrabify: true
                selection_type: "single"
                boxSelectionEnabled: false
                container: $("#graph_container")
                elements: data
                style: self.getStyles()
            })
            self.refreshLayout()

            self.cy.on "unselect", "node", (event)->
                if self.cy.nodes(":selected").length == 0
                    $("#selected_node_panel").hide()

            self.cy.on "select", "node", (event)->
                $("#selected_node_panel").show()
                self.cy.elements().not(event.target).unselect()
                if event.target.data('type') == "SplitByFacet" or event.target.data('class') == "analysis_tool"
                    # Attributes panel
                    $("#type_attr").html event.target.data('type')
                    $("#id_attr").html event.target.data('id')
                    $("#params_attr").html ""
                    params = event.target.data('parameters')
                    for param of params
                        $("#params_attr").append "<p class=\"collection_param\"><span style=\"color: #888888; font-weight: bold;\">#{param}: </span>#{params[param]}</p>"
                    $("#node_attrs .add_output").remove()

                    # Task panel

                else if event.target.data('type') == "dataset" # or event.target.data('type') == "placeholder_collections"
                    # Attributes panel
                    $("#type_attr").html event.target.data('type')
                    $("#id_attr").html event.target.data('id')
                    $("#params_attr").html ""
                    if event.target.data('params').source == "search_query"
                        query = event.target.data('params').search_query
                        mapping = {'q': 'Query', 'fq': "Filter"}
                        for param of query
                            if Array.isArray query[param]
                                for p in query[param]
                                    if mapping[param] != undefined
                                        $("#params_attr").append "<p class=\"collection_param\"><span style=\"color: #888888; font-weight: bold;\">#{mapping[param]}: </span>#{p}</p>"
                            else if mapping[param] != undefined
                                $("#params_attr").append "<p class=\"collection_param\" ><span style=\"color: #888888; font-weight: bold;\">#{mapping[param]}: </span>#{query[param]}</p>"
                    else if event.target.data('params').source == "dataset"
                        $("#params_attr").append "<p class=\"collection_param\"><span style=\"color: #888888; font-weight: bold;\">Dataset: </span><a href=\"/datasets/#{event.target.data('params').source_id}\">#{event.target.data('params').source_name}</a></p>"
                    $("#outputs_attr").html ""
                    $("#inputs_attr").html ""

                $("#add_output_button").off "click"
                $("#add_output_button").on "click", (e)->
                    $.ajax {
                        url:  window.location.protocol+"//"+window.location.host+'/experiment/add_output_modal',
                        method: 'POST',
                        dataType: "script",
                        data:{node_type: event.target.data('type')}
                    }

    addNode: (data)->
        self = @
        self.cy.add {
            group: 'nodes'
            data: data
        }
        self.refreshLayout()
        self.save_graph()

    removeNode: (node)->
        self = @
        self.cy.remove(node.successors())
        self.cy.remove(node)
        self.refreshLayout()
        self.save_graph()

    addEdge: (origin, dest, opts = null)->
        self = @
        data = {
            id: "edge_#{self.getNextId("edge")}"
            source: origin
            target: dest
        }
        $.extend data, opts
        self.cy.add {
            group: 'edges'
            data: data
        }
        self.refreshLayout()
        self.save_graph()

    refreshLayout: ()->
        self = @
        self.cy.edges().unselect()
        self.cy.edges().unselectify()
        self.cy.nodes('[type = "placeholder_collection" ]').unselect()
        self.cy.nodes('[type = "placeholder_collection" ]').unselectify()
        self.cy.elements().layout(self.getLayout()).run()

    getNextId: (prefix)->
        self = @
        ids = []
        $.each self.cy.elements(), (i, val)->
            if val.data('id').indexOf(prefix) == 0
                ids.push(parseInt(val.data('id').split("_").pop(), 10))
        return 1 if ids.length == 0
        return Math.max.apply(null, ids)+1

    create_parameters_modal: (selected_node)->
        alert selected_node.data()


    create_add_output_modal: ()->
        self = @
        html_code1 = [
            "<div>",
            "    <div class='modal-header'>",
            "        <button type='button' class='close' data-dismiss='modal'>x</button>",
            "        <h4 class='modal-title' id='params_label'>Add an output</h4>",
            "    </div>",
            "    <div class='modal-body'>",
            "        <form id='add_output_tool'>",
            "            <label for='output_tool_select'>Add a tool to the output</label>",
            "            <select id='output_tool_select' name='output_tool_select' class='form-control' autocomplete='off'>",
            "                <option value='' disabled selected>Select a tool</option>"
        ]
        options = [
            "                <option value='ExtractFacet'>ExtractFacet</option>"
            "                <option value='ExtractWords'>ExtractWords</option>"
            "                <option value='ExtractBigrams'>ExtractBigrams</option>"
            "                <option value='SplitByFacet'>SplitByFacet</option>"
        ]
        html_code2 = [
            "            </select>",
            "            <button id='add_output_button' class='btn btn-primary' type='button'>Add new tool</button>",
            "        </form>",
            "    </div>",
            "</div>"
        ]

        html_code = html_code1.concat(options.concat html_code2)
        modal = $(html_code.join("\n"))

        $("#modal-add_output").off "click", 'button#add_output_button'
        $("#modal-add_output").on "click", 'button#add_output_button', (event)->
            tool_type =$("#output_tool_select option:selected").val()
            if tool_type != ""
                if tool_type == "SplitByFacet"
                    placeholder_ids = []
                    added_node_id = "#{tool_type}_#{self.getNextId(tool_type)}"
                    plchld_id = self.getNextId("placeholder")
                    placeholder_id = "placeholder_#{plchld_id}"
                    placeholder_ids.push placeholder_id
                    self.addNode {
                        id: placeholder_id
                        type: "placeholder_collection"
                        inputs: [added_node_id]
                    }
                    placeholder_id = "placeholder_#{plchld_id+1}"
                    placeholder_ids.push placeholder_id
                    self.addNode {
                        id: placeholder_id
                        type: "placeholder_collection"
                        inputs: [added_node_id]
                    }
                    self.addNode {
                        id: added_node_id
                        type: tool_type
                        results: {
                            created_text_collections: placeholder_ids
                        }
                    }
                    self.addEdge self.cy.nodes(":selected")[0].data('id'), added_node_id, {type: "final"}
                    for placeholder_id in placeholder_ids
                        self.addEdge added_node_id, placeholder_id, {type: "temporary"}
                else
                    added_node_id = "#{tool_type}_#{self.getNextId(tool_type)}"
                    self.addNode {
                        id: added_node_id
                        type: tool_type
                        class: "analysis_tool"
                        inputs: [self.cy.nodes(":selected")[0].data('id')]
                        results: {}
                    }
                    self.addEdge self.cy.nodes(":selected")[0].data('id'), added_node_id, {type: "final"}
                $('#modal-add_output').modal('hide')
                self.cy.$("##{added_node_id}").select()
            event.preventDefault()
            return false

        return modal.html()

    createSVG: (node)->
        if node.data('type') == "dataset"
            return SVGUtils.text_collection node.data('params').source
        if node.data('type') == "SplitByFacet"
            return SVGUtils.split_by_facet node.data('task_status')
        if node.data('class') == "analysis_tool"
            return SVGUtils.analysis_tool node.data('task_status'), node.data("type")

    getStyles: ->
        self = @
        return [
            {
                selector: 'node[type = "dataset"]'
                style: {
                    "shape": "roundrectangle"
                    #"background-color": "#457B9D"
                    "background-image": (ele)->
                        return self.createSVG(ele).svg
                    "width": (ele)->
                        return self.createSVG(ele).width
                    "height": (ele)->
                        return self.createSVG(ele).height
                    "border-style": "solid"
                    "border-width": 1
                    "border-opacity": 0.5
                    "border-color": "#1D3557"
#                     "label": (ele)->
#                         if ele.data('params')['source'] == "dataset"
#                             return "Dataset: #{ele.data('params')['source_name']}"
#                         else if ele.data('params')['source'] == "search_query"
#                             return "Search: #{ele.data('params')['source_name']}"
                }
            }
            {
                selector: 'node[type = "dataset"]:selected'
                style: {
                    "shape": "roundrectangle"
                    "background-color": "#457B9D"
                    "border-style": "solid"
                    "border-width": 2
                    "border-opacity": 1
                    "border-color": "#1D3557"
#                     "label": (ele)->
#                         if ele.data('params')['source'] == "dataset"
#                             return "Dataset: #{ele.data('params')['source_name']}"
#                         else if ele.data('params')['source'] == "search_query"
#                             return "Search: #{ele.data('params')['source_name']}"
                }
            }
            {
                selector: 'node[type = "placeholder_collection"]'
                style: {
                    "shape": "roundrectangle"
                    "background-color": "#457B9D"
                    "border-style": "dotted"
                    "background-opacity": "0.3"
                    "label": "Subdataset"
                    "text-opacity": "0.3"
                }
            }
            {
                selector: 'node[class = "analysis_tool" ][task_status = "not started"]'
                style: {
                    "shape": "roundrectangle"
# "background-color": "#F1FAEE"
                    "background-image": (ele)->
                        return self.createSVG(ele).svg
                    "width": (ele)->
                        return self.createSVG(ele).width
                    "height": (ele)->
                        return self.createSVG(ele).height
                    "border-style": "solid"
                    "border-width": 1
                    "border-opacity": 0.5
#                     "label": (ele)->
#                         return ele.data('type')
                }
            }
            {
                selector: 'node[class = "analysis_tool" ][task_status = "running"]'
                style: {
                    "shape": "roundrectangle"
# "background-color": "#F1FAEE"
                    "background-image": (ele)->
                        return self.createSVG(ele).svg
                    "width": (ele)->
                        return self.createSVG(ele).width
                    "height": (ele)->
                        return self.createSVG(ele).height
                    "border-style": "solid"
                    "border-width": 1
                    "border-opacity": 0.5
#                     "label": (ele)->
#                         return ele.data('type')
                }
            }
            {
                selector: 'node[class = "analysis_tool" ][task_status = "finished"]'
                style: {
                    "shape": "roundrectangle"
# "background-color": "#F1FAEE"
                    "background-image": (ele)->
                        return self.createSVG(ele).svg
                    "width": (ele)->
                        return self.createSVG(ele).width
                    "height": (ele)->
                        return self.createSVG(ele).height
                    "border-style": "solid"
                    "border-width": 1
                    "border-opacity": 0.5
#                     "label": (ele)->
#                         return ele.data('type')
                }
            }
            {
                selector: 'node[class = "analysis_tool" ]:selected'
                style: {
                    "shape": "roundrectangle"
                    "background-color": "#F1FAEE"
                    "border-style": "solid"
                    "border-width": 3
                    "border-opacity": 1
                    "border-color": "#1D3557"
#                     "label": (ele)->
#                         return ele.data('type')
                }
            }
            {
                selector: 'node[type = "SplitByFacet" ]'
                style: {
                    "shape": "diamond"
                    # "background-color": "#A8DADC"
                    "background-image": (ele)->
                        return self.createSVG(ele).svg
                    "width": (ele)->
                        return self.createSVG(ele).width
                    "height": (ele)->
                        return self.createSVG(ele).height
                    "border-style": "solid"
                    "border-width": 1
                    "border-opacity": 0.5
                    "border-color": "#1D3557"
#                     "label": (ele)->
#                         return ele.data('type')
                }
            }
            {
                selector: 'node[type = "SplitByFacet" ]:selected'
                style: {
                    "shape": "diamond"
                    "background-color": "#A8DADC"
                    "border-style": "solid"
                    "border-width": 2
                    "border-opacity": 1
                    "border-color": "#1D3557"
#                     "label": (ele)->
#                         return ele.data('type')
                }
            }
            {
                selector: 'edge[type = "temporary"  ]'
                style: {
                    "line-style": "dashed"
                    "target-arrow-shape": "triangle"

                }
            }
            {
                selector: 'edge[type = "final"  ]'
                style: {
                    "line-style": "solid"
                    "target-arrow-shape": "triangle"

                }
            }
            # Status: selected, not selected
            # Status: to_run (new node or params changed), running, finished, failed
            # node type: text_collection, analysis_tool, SplitByFacet (edge ?)
        ]

    getLayout: ->
        self = @
        layout_options = {
            name: "dagre"
            nodeSep: 10, # the separation between adjacent nodes in the same rank
            edgeSep: undefined, # the separation between adjacent edges in the same rank
            rankSep: 100, # the separation between each rank in the layout
            rankDir: "TB", # 'TB' for top to bottom flow, 'LR' for left to right,
            ranker: undefined, # Type of algorithm to assign a rank to each node in the input graph. Possible values: 'network-simplex', 'tight-tree' or 'longest-path'
            minLen: (edge)-> # number of ranks to keep between the source and target of the edge
                return 1
            edgeWeight: (edge)-> # higher weight edges are generally made shorter and straighter than lower weight edges
                return 1
            # general layout options
            fit: true, # whether to fit to viewport
            padding: 30, # fit padding
            spacingFactor: undefined, # Applies a multiplicative factor (>0) to expand or compress the overall area that the nodes take up
            nodeDimensionsIncludeLabels: true, # whether labels should be included in determining the space used by a node
            animate: false, # whether to transition the node positions
            animateFilter: (node, i)-> # whether to animate specific nodes when animation is on; non-animated nodes immediately go to their final positions
                return true
            animationDuration: 500, # duration of animation in ms if enabled
            animationEasing: undefined, # easing of animation if enabled
            boundingBox: undefined, # constrain layout bounds; { x1, y1, x2, y2 } or { x1, y1, w, h }
            transform: (node, pos)-> # a function that applies a transform to the final node position
                return pos
            ready: (->), # on layoutready
            stop: (->)# on layoutstop
        }
        return layout_options

    build_panel: ->


    save_graph: ->
        self = @
        to_save = self.cy.elements().jsons()
        to_save = $.map to_save, (elt)->
            elt.selected = false
            return elt
        API.save_graph JSON.stringify(to_save), @experiment_id, (data)->
            return
