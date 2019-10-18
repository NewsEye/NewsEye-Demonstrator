class @PersonalResearchAssistantIndex
    constructor: ->
        console.log "PRA index specific"
        @setup_submit("analysis", "search_task")
        @setup_submit("analysis", "dataset")
        @setup_submit("investigate", "search_task")
        @setup_submit("investigate", "dataset")
        @utilities = JSON.parse $("#utilities").text()
        @topic_models= JSON.parse $("#topic_models").text()
        @user_tasks_uuids = JSON.parse $("#user_tasks_uuids").text()
        @setup_utilities()

    setup_submit: (task_type, data_source)->
        $("input[name=\"#{task_type}_#{data_source}_submit\"]").click (e) ->
            e.preventDefault()
            if task_type == "analysis"
                select = $("#utilities_select")[0]
                if select.selectedIndex == 0
                    alert 'Please select a utility to run'
                    return
            if $("##{task_type}_#{data_source}_select")[0].selectedIndex == 0
                if data_source == "search_task"
                    alert "Please select a search task"
                if data_source == "dataset"
                    alert "Please select a dataset"
            else
                input = document.createElement("input")
                input.setAttribute("type", "hidden")
                input.setAttribute("name", "source_select")
                input.setAttribute("value", data_source)
                $("##{task_type}_data_source_form").append(input)
                Rails.fire($("##{task_type}_data_source_form")[0], 'submit')

    render_comparison_tasks: ->
        container_node = $("<div></div>")
        panel_div = $("<div class=\"panel panel-default\"></div>")
        panel_heading_div = $("<div class=\"panel-heading\"><h3 class=\"panel-title\">Task UUIDs</h3></div>")
        panel_body_div = $("<div class=\"panel-body\" style=\"height: 200px; overflow-y: scroll; padding: 0px;\"></div>")
        list = $("<ul class=\"list-group\" id=\"select_tasks_list\">")
        tasks_to_compare = {}
        for task in @user_tasks_uuids
            if tasks_to_compare.hasOwnProperty task.input_type
                tasks_to_compare[task.input_type].push $("<li class=\"list-group-item\"><input type=\"checkbox\" value=\"\">#{task.uuid}</li>")
            else
                tasks_to_compare[task.input_type] = []
                tasks_to_compare[task.input_type].push $("<li class=\"list-group-item\"><input type=\"checkbox\" value=\"\">#{task.uuid}</li>")
        for input_type, comparable_tasks of tasks_to_compare
            $("<li class=\"list-group-item-heading\" style=\"padding-left:10px; font-weight: bold;\">#{input_type}</li>").appendTo list
            for task in comparable_tasks
                task.appendTo list
        list.appendTo panel_body_div
        panel_heading_div.appendTo panel_div
        panel_body_div.appendTo panel_div
        input = $("<input type=\"hidden\" name=\"utility_params[task_uuids][]\" />")
        input2 = $("<input type=\"hidden\" name=\"source_select\" value=\"none\"/>")
        input3 = $("<input type=\"hidden\" name=\"utilities_select\" value=\"comparison\"/>")
        button = $("<button type=\"submit\" class=\"btn btn-primary\" name=\"submit\">Compare tasks</button>")
        panel_div.appendTo container_node
        input.appendTo container_node
        input2.appendTo container_node
        input3.appendTo container_node
        button.appendTo container_node
        $('#utility_params_inputs').html(container_node.html())
        $("#analysis_data_source_form").submit ->
            tasks = []
            for elt in $('ul#select_tasks_list li input:checked').toArray()
                tasks.push(elt.parentNode.textContent)
            console.log tasks
            $('input:hidden[name=\'utility_params[task_uuids][]\']').val(tasks)
            return true

    render_topic_model_task: ->
        container_node = $("<div></div>")
        row = $("<div class=\"row\"></div>")
        col1 = $("<div class=\"col-md-3\"></div>")
        col2 = $("<div class=\"col-md-9\"></div>")
        label = $("<label for=\"model_pra_select\">Select the model to use</label>")
        select = $('<select id="model_pra_select" name="model_pra_select" class="form-control" autocomplete="off"></select>')
        describe_topic_div = $('<div id=\"describe_topic_div\" class=\"row\"></div>')
        opt = $('<option value="" disabled selected>Select the model to use</option>')
        select.append opt
        for model_type, available_models of @topic_models
            optgroup = $("<optgroup label=\"#{model_type}\"></optgroup>")
            if typeof available_models != "string"
                for data in available_models
                    opt = $("<option value=\"#{model_type}|#{data['name']}\">#{data['description']}</option>")
                    optgroup.append opt
                select.append optgroup
        col1.append label
        col2.append select
        row.append col1
        row.append col2
        container_node.append row
        container_node.append describe_topic_div
        $('#utility_params_inputs').html(container_node.html())

    setup_utilities: ->
        self = @
        $('#utilities_select').change ->
            obj = self.utilities.find (u)->
                u.utility_name == $('#utilities_select option:selected').attr('value')
            $('#utility_params_inputs').html('')
            $('#utility_desc').html('')
            $('#dataset_pra_select').val('')
            $('#query_pra_input').val('')
            util_desc = document.createElement('p')
            util_desc.textContent = obj.utility_description
            $('#utility_desc').append(util_desc)
            if obj.utility_name == 'query_topic_model'
                self.render_topic_model_task()
                $('#model_pra_select').change ->
                    $('#describe_topic_div').html('')
                    col1 = $('<div class=\"col-md-3\"></div>')
                    col2= $('<div class=\"col-md-7\"></div>')
                    col3 = $('<div class=\"col-md-2\"></div>')
                    label = $('<label for=\"topic_select\">Select a topic to describe:</label>')
                    col1.append label
                    select_topic = $('<select id=\"topic_select\" name=\"topic_select\" class=\"form-control\"></select>')
                    opt = $('<option value="" disabled selected>Select a topic</option>')
                    select_topic.append opt
                    for i in [0...10] by 1
                        select_topic.append $("<option value=\"#{i}\">Topic #{i}</option>")
                    col2.append select_topic
                    model_type = $('#model_pra_select option:selected').attr('value').split('|')[0]
                    model_name = $('#model_pra_select option:selected').attr('value').split('|')[1]
                    button = $("<a class=\"btn btn-info\">Describe</a>")
                    button.click (e)->
                        form = $('<form id="temp_topic_form" method="post" action="/personal_research_assistant/tm_action" data-remote="true"></form>')
                        form.append $("<input type=\"hidden\" name=\"model_type\" value=\"#{model_type}\"></input>")
                        form.append $("<input type=\"hidden\" name=\"model_name\" value=\"#{model_name}\"></input>")
                        topic_id = $('#topic_select option:selected').attr('value')
                        form.append $("<input type=\"hidden\" name=\"topic_id\" value=\"#{topic_id}\"></input>")
                        $(document.body).append(form)
                        Rails.fire($('#temp_topic_form')[0], 'submit')
                        form.remove()
                    col3.append button
                    $('#describe_topic_div').append col1
                    $('#describe_topic_div').append col2
                    $('#describe_topic_div').append col3
            else
                for param in obj.utility_parameters
                    if !(obj.utility_name == "comparison" && param.parameter_name == "task_ids")
                        if obj.utility_name == "comparison" && param.parameter_name == "task_uuids"
                            self.render_comparison_tasks()
                            $('#select_tasks_list li').click (e)->
                                e.preventDefault()
                                that = $(e.target)
                                classlist = that.attr('class').split(/\s+/)
                                if classlist.includes('active')
                                    that.find('input')[0].checked = false
                                    classlist.splice( classlist.indexOf('active'), 1 )
                                else
                                    that.find('input')[0].checked = true
                                    classlist.push('active')
                                that.attr('class', classlist.join(' '))
                            $('#compare_tasks_form').submit ->
                                tasks = []
                                for element in $('ul#select_tasks_list li input:checked').toArray()
                                    tasks.push(element.parentNode.textContent)
                                $('input:hidden[name=\'tasks[]\']').val(tasks)
                                return true
                        else
                            parameter_container = document.createElement('div')
                            parameter_container.className = "utility_parameter_container row"
                            input_id = obj.utility_name + '_' + param.parameter_name + '_input'
                            label = document.createElement('label')
                            label.setAttribute('for', input_id)
                            textContent = param.parameter_name.split('_').join(' ')
                            textContent = textContent.charAt(0).toUpperCase() + textContent.slice(1)
                            label.textContent = textContent
                            tooltip = document.createElement('span')
                            tooltip.setAttribute("style", "margin-left: 20px;")
                            tooltip.className = "glyphicon glyphicon-question-sign"
                            tooltip.setAttribute('title', param.parameter_description)
                            label.appendChild(tooltip)

                            input = document.createElement('input')
                            input.setAttribute('id', input_id)
                            input.name = "utility_params[" + param.parameter_name + "]"
                            input.value = param.parameter_default
                            input.className = "form-control"
                            switch param.parameter_type
                                when 'string'
                                    input.type = 'text'
                                when 'integer'
                                    input.type = 'number'
                            parameter_container.appendChild(label)
                            parameter_container.appendChild(input)
                            $('#utility_params_inputs').append(parameter_container)