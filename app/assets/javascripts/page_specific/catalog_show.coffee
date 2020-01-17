class @CatalogShow
    constructor: ->
        self = @
        console.log 'show'
        @setup_select()
        if $("#current_document_id").text().includes "_article_"
            @set_article_image()
        else # if issue
            console.log "issue"

    setup_select: ->
        self = @
        $("#working_dataset_select").change ->
            Rails.fire($('#working_dataset_select').parent()[0], 'submit')

    change_page: (pagenum)->
        wid = mirador_instance.viewer.workspace.windows[0].id
        url = window.location.protocol + "//" + window.location.host
        canvasID = url + "/iiif/" + $("#current_document_id").text() + "/canvas/page_#{pagenum}" # #{annot['selector']}"
        mirador_instance.eventEmitter.publish('SET_CURRENT_CANVAS_ID.' + wid, canvasID)

    change_view: (x, y, width, height)->
        wid = mirador_instance.viewer.workspace.windows[0].id
        mirador_instance.eventEmitter.publish('fitBounds.'+wid, {'x': x, 'y': y,'width': w, 'height': h})

    promiseOfAllImages: (parts)->
        # Wait until ALL images are loaded
        return Promise.all parts.map (part)->
            # Load each tile, and "resolve" when done
            return new Promise (resolve)->
                img = new Image()
                img.src = part[0]
                img.onload = ()->
                    # Image has loaded... resolve the promise!
                    resolve( [img, [ part[1][0], part[1][1] ]] )

    set_article_image: ->
        self = @
        canvas = $('#article_composite_image')
        ctx = canvas[0].getContext('2d')
        article_id = $('#current_document_id').text()
        API.get_article_images article_id, (data)->
            # set canvas size
            canvas[0].width = data['canvas_size'][0]
            canvas[0].height = data['canvas_size'][1]
            # draw images
            self.promiseOfAllImages(data['parts']).then (parts) ->
                for part in parts
                    ctx.drawImage part[0], part[1][0], part[1][1]
