class @PersonalResearchAssistantIndex
    constructor: ->
        self = @
        API.utilities (utilities)->
            self.utilities = utilities
            API.topic_models (models)->
                self.topic_models = models
                API.user_tasks utilities, (tasks)->
                    self.user_tasks_uuids = tasks
                    self.setup_utilities()

    reload_tasks: ->
        self = @
        API.user_tasks self.utilities, (tasks)->
            self.user_tasks_uuids = tasks

    setup_utilities: ->
        self = @
        $('#utilities_select').change ->
            obj = self.utilities.find (u)->
                u.utility_name == $('#utilities_select option:selected').attr('value')
            API.render_utility obj, self.topic_models, self.user_tasks_uuids,  (content)->
                $('#selected_utility').html(content)
                # Describe topic
                $('#describe_topic_button').click (e)->
                    model_type = $('#model_pra_select option:selected').attr('value').split('|')[0]
                    model_name = $('#model_pra_select option:selected').attr('value').split('|')[1]
                    form = $("<form id=\"temp_topic_form\" method=\"post\" action=\"/personal_research_assistant/tm_action\" data-remote=\"true\"></form>")
                    form.append $("<input type=\"hidden\" name=\"model_type\" value=\"#{model_type}\"></input>")
                    form.append $("<input type=\"hidden\" name=\"model_name\" value=\"#{model_name}\"></input>")
                    topic_id = $('#topic_select option:selected').attr('value')
                    form.append $("<input type=\"hidden\" name=\"topic_id\" value=\"#{topic_id}\"></input>")
                    $(document.body).append(form)
                    Rails.fire($('#temp_topic_form')[0], 'submit')
                    form.remove()
                # Task selection in comparison analysis
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
                # Comparison analysis submit
                $("#analysis_form").submit ->
                    if $('ul#select_tasks_list').length
                        checked = $('ul#select_tasks_list li input:checked').toArray()
                        console.log checked
                        tasks = []
                        for elt in checked
                            tasks.push(elt.parentNode.textContent)
                        $('input:hidden[name=\'utility_params[task_uuids][]\']').val(tasks)
                    return true
                $('#tasks_comparison_submit').click (e)->

                # Validations analyse search
                $('input[name=\'analysis_search_task_submit\']').click (e)->
                    e.preventDefault()
                    selected =  $('select#analysis_search_task_select').children("option:selected").val()
                    if selected == ""
                        alert "Please select a search."
                    else
                        Rails.fire($('#analysis_form')[0], 'submit')
                # Validations analyse dataset
                $('input[name=\'analysis_dataset_submit\']').click (e)->
                    e.preventDefault()
                    selected =  $('select#analysis_dataset_select').children("option:selected").val()
                    if selected == ""
                        alert "Please select a dataset."
                    else
                        Rails.fire($('#analysis_form')[0], 'submit')
                # Validations investigate search
                $('input[name=\'investigate_search_task_submit\']').click (e)->
                    e.preventDefault()
                    selected =  $('select#investigate_search_task_select').children("option:selected").val()
                    if selected == ""
                        alert "Please select a search."
                    else
                        Rails.fire($('#investigate_data_source_form')[0], 'submit')
                # Validations investigate dataset
                $('input[name=\'investigate_dataset_submit\']').click (e)->
                    e.preventDefault()
                    selected =  $('select#investigate_dataset_select').children("option:selected").val()
                    if selected == ""
                        alert "Please select a dataset."
                    else
                        Rails.fire($('#investigate_data_source_form')[0], 'submit')