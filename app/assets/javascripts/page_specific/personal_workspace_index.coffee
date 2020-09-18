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
