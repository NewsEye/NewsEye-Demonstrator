class @PersonalWorkspaceFlowy
    constructor: ->
        self = @
        console.log 'flowy'
        @init()

    init: ->
        spacing_x = 40
        spacing_y = 100
        onGrab = (block)->
            console.log("grabbed")
        onRelease = ()->
            console.log("released")
        onSnap =  (block, first, parent)->
            console.log("snapped")
        onRearrange =  (block, parent)->
            console.log("rearranged")

        flowy(document.getElementById("panel_canvas"), onGrab, onRelease, onSnap, onRearrange, spacing_x, spacing_y);