class @PersonalResearchAssistantIndex
    constructor: ->
        console.log "PRA index specific"
        @setup_submit("analysis", "search_task")
        @setup_submit("analysis", "dataset")
        @setup_submit("investigate", "search_task")
        @setup_submit("investigate", "dataset")
        @utilities = JSON.parse $("#utilities").text()
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
                label = document.createElement('label')
                label.setAttribute('for', 'model_pra_select')
                label.textContent = 'Select the model to use'
                select = $('#model_tm_select').clone()
                select.attr('id', "model_pra_select")
                select.attr('name', "model_pra_select")
                $('#utility_params_inputs').append(label)
                $('#utility_params_inputs').append(select)
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
                            parameter_container.className = "utility_parameter_container"
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