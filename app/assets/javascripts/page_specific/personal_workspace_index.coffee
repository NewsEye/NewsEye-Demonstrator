class @PersonalWorkspaceIndex
    constructor: ->
        self = @
        console.log 'index'
        $($("#refresh_tasks_form button")[0]).click ()->
            $("body").css("cursor", "wait")

        $('#menu_list li').click (e)->
            tab_id = $(e.currentTarget).data('div')
            $(".menu_tab").hide()
            $("##{tab_id}").show()
            $("#menu_list li").removeClass("active")
            $(e.currentTarget).addClass("active")

        $("body").on "click", "#create_experiment_button", (e)->
            title = $(e.currentTarget).parent().find("input[type='text']")[0].value
            $("#create_experiment_log").show()
            $("#create_experiment_log").css("font-weight", "bold")
            if title.match /^.*[0-9a-z].*$/
                Rails.fire($('#create_experiment_form')[0], 'submit')
            else
                $("#create_experiment_log").css("color", "red")
                $("#create_experiment_log").text "The title must contain at least one alphanumeric character."
                e.preventDefault()

        $("body").on "click", ".start_experiment_button", (e)->
            $("div#main-flashes div:first-child").empty()
            log = $('<div class="alert alert-info">Creating a new Experiment...<a class="close" data-dismiss="alert" href="#">×</a></div>')
            $("div#main-flashes div:first-child").append(log)

        $("#new_experiment_link").on "click", (e)->
            $.ajax {
                url:  window.location.protocol+"//"+window.location.host+'/personal_workspace/create_experiment',
                method: 'GET',
                dataType: "script"
            }
            e.preventDefault()