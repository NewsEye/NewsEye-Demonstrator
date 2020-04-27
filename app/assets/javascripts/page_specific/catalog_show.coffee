class @CatalogShow
    constructor: ->
        self = @
        console.log 'show'
        @setup_select()
        if $("#current_document_id").text().includes "_article_"
            @set_article_image()
        else # if issue
            console.log "issue"
            @load_mirador()
            @setup_from_article_links()

    setup_from_article_links: ->
        self = @
        if $("#goto_page")
            $("#goto_page").click (e)->
                $("#goto_location").css('display', '')
                self.change_page $(e.target).data('page')
        if $("#goto_location")
            $("#goto_location").click (e)->
                loc = $(e.target).data('location')
                self.change_view loc[0], loc[1], loc[2], loc[3]

    setup_select: ->
        self = @
        $("#working_dataset_select").change ->
            Rails.fire($('#working_dataset_select').parent()[0], 'submit')

    load_mirador: ->
        self = @
        doc_id = window.location.href.split("/").slice(-1)[0]
        doc_id = doc_id.split('?')[0]
        API.get_mirador_config doc_id, (config)->
            self.mirador_instance = Mirador(config)
#             handler_func = ()->
#                 console.log("rendered")
#             self.mirador_instance.eventEmitter.subscribe('manifestListItemRendered', handler_func)
#             handler_func2 = ()->
#                 console.log("received")
#             self.mirador_instance.eventEmitter.subscribe('manifestReceived', handler_func2)
#             handler_func4 = ()->
#                 console.log("window added")
#                 wid = self.mirador_instance.viewer.workspace.windows[0].id
# #                 self.change_page 4
# #                 self.change_view 300,300,200,400
#                 handler_func3 = ()->
#                     console.log("osd ready")
#                 self.mirador_instance.eventEmitter.subscribe('osdOpen.' + wid, handler_func3)
#             self.mirador_instance.eventEmitter.subscribe('windowAdded', handler_func4)
#             handler_func5= (wid,bnds)->
#                 console.log("bounds")
#                 console.log(bnds)
#             self.mirador_instance.eventEmitter.subscribe('imageBoundsUpdated', handler_func5)
#
#     go_to: (pagenum, x, y, width, height)->
#         @change_page(pagenum)
#         @change_view(x, y, width, height)

    change_page: (pagenum)->
        self = @
        wid = self.mirador_instance.viewer.workspace.windows[0].id
        url = window.location.protocol + "//" + window.location.host
        canvasID = url + "/iiif/" + $("#current_document_id").text() + "/canvas/page_#{pagenum}" # #{annot['selector']}"
        self.mirador_instance.eventEmitter.publish('SET_CURRENT_CANVAS_ID.' + wid, canvasID)

    change_view: (x, y, width, height)->
        self = @
        wid = self.mirador_instance.viewer.workspace.windows[0].id
        self.mirador_instance.eventEmitter.publish('fitBounds.'+wid, {'x': x, 'y': y,'width': width, 'height': height})

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
