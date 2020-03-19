class @PersonalWorkspaceIndex
    constructor: ->
        self = @
        console.log 'index'
        $($("#refresh_tasks_form button")[0]).click ()->
            $("body").css("cursor", "wait")