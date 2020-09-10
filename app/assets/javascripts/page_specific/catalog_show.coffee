class @CatalogShow

    maskN = null
    maskE = null
    maskS = null
    maskW = null
    isDragged = false

    constructor: ->
        self = @
        console.log 'show'
        @setup_select()
        @load_osd()

    setup_select: ->
        self = @
        $("#working_dataset_select").change ->
            Rails.fire($('#working_dataset_select').parent()[0], 'submit')

        # datasets memberships
        API.get_datasets_with_doc $("#current_document_id").text(), (data)->
            if data.length > 0
                datasets =$("<p style=\"font-style: italic;\">Currently belongs to: </p>")
                for obj in data
                    relevancy_mapping = {0: ['dark', 'Not relevant'], 1: ['light', 'Somewhat relevant'], 2: ['info', 'Relevant'], 3: ['primary', 'Very relevant']}
                    badge_type = relevancy_mapping[obj[2]][0]
                    tooltip = relevancy_mapping[obj[2]][1]
                    a = $("<a href=\"/datasets/#{obj[0]}\"></a>")
                    span = $("<span class=\"dataset-#{obj[0]} badge badge-#{badge_type}\" title=\"#{tooltip}\" data-relevancy=\"#{obj[2]}\">#{obj[1]}</span>")
                    a.append span
                    datasets.append a
                $("#issue_in_datasets_list").html datasets[0].outerHTML
            else
                $("#issue_in_datasets_list").html ""

    load_osd: ->
         self = @
         pages_urls = $('#openseadragon_view').data("pages")
         articles = $('#openseadragon_view').data("articles")
         urlParams = new URLSearchParams(window.location.search)
         initialPage = 0
         if window.location.hash != ""
            article_id = window.location.hash.slice(1)
            found = false
            for pagenum of articles
                for article in articles[pagenum]
                    if article.id == article_id
                        found = true
                        initialPage = pagenum - 1
                        break
                break if found
         self.set_current_page initialPage+1
         self.viewer = OpenSeadragon({
             id: "openseadragon_view",
             prefixUrl: "/openseadragon/images/",
             sequenceMode: true,
             initialPage: initialPage,
             showReferenceStrip: false,
             tileSources: pages_urls,
             nextButton:     "page_next",
             previousButton: "page_previous"
         })

         self.viewer.addHandler("page", (data)->
             self.set_current_page(data.page+1)
             self.display_article_text null
         )

         self.viewer.addHandler("open", (data)->
             $('.openseadragon-container > div:nth-child(2)').css('z-index', 4 )
             article_id = null
             if window.location.hash != ""
                article_id = window.location.hash.slice(1)
             pagenum = self.viewer.currentPage()
             for article in articles[pagenum+1]
                 bbox = article['bbox']
                 loc = self.viewer.viewport.imageToViewportRectangle(bbox[0], bbox[1], bbox[2], bbox[3])
                 if article_id == article.id
                    article_class =  "selected_article_highlight"
                    self.display_mask(loc)
                    self.display_article_text article
                    self.viewer.viewport.zoomTo(2, new OpenSeadragon.Point(loc.x+loc.width/2, loc.y+loc.height/2))
                    self.set_article_dataset_form(article_id)
                 else
                    article_class =  "base_article_highlight"
                 elt = $("<div id=\"#{article['id']}\" class=\"#{article_class}\"></div>")
                 elt.attr("data-loc", JSON.stringify({'x': loc.x, 'y': loc.y, 'width': loc.width, 'height': loc.height}))
                 elt.attr("data-text", JSON.stringify(article['all_text']))
                 self.viewer.addOverlay
                     element: elt[0]
                     location: loc
                 tracker = new OpenSeadragon.MouseTracker({
                     clickDistThreshold: 30,
                     element: elt[0],
                     dragHandler: (event)->
                        elt = event.eventSource.element
                        $(elt).attr('data-noclick', true)
                        # copy and adpated from Viewer.onCanvasDrag()
                        gestureSettings = null
                        canvasDragEventArgs = {
                            tracker: event.eventSource,
                            position: event.position,
                            delta: event.delta,
                            speed: event.speed,
                            direction: event.direction,
                            shift: event.shift,
                            originalEvent: event.originalEvent,
                            preventDefaultAction: event.preventDefaultAction
                        }
                        if !canvasDragEventArgs.preventDefaultAction && self.viewer.viewport
                            gestureSettings = self.viewer.gestureSettingsByDeviceType( event.pointerType )
                            event.delta.x = 0 unless self.viewer.panHorizontal
                            event.delta.y = 0 unless self.viewer.panVertical
                            event.delta.x = -event.delta.x if self.viewer.viewport.flipped
                            if self.viewer.constrainDuringPan
                                delta = self.viewer.viewport.deltaPointsFromPixels( event.delta.negate() )
                                self.viewer.viewport.centerSpringX.target.value += delta.x
                                self.viewer.viewport.centerSpringY.target.value += delta.y
                                bounds = self.viewer.viewport.getBounds()
                                constrainedBounds = self.viewer.viewport.getConstrainedBounds()
                                self.viewer.viewport.centerSpringX.target.value -= delta.x
                                self.viewer.viewport.centerSpringY.target.value -= delta.y
                                event.delta.x = 0 if bounds.x != constrainedBounds.x
                                event.delta.y = 0 if bounds.y != constrainedBounds.y
                            self.viewer.viewport.panBy( self.viewer.viewport.deltaPointsFromPixels( event.delta.negate() ), gestureSettings.flickEnabled && !self.viewer.constrainDuringPan)
                     clickHandler: (event)->
                         elt = event.eventSource.element
                         if $(elt).attr('data-noclick') != undefined
                             $(elt).removeAttr('data-noclick')
                         else
                             self.hide_mask()
                             self.set_article_dataset_form null
                             # one overlay can be selected at a time
                             if $(elt).attr('class') != "selected_article_highlight"
                                 for e in $(".selected_article_highlight")
                                     $(e).attr("class", "base_article_highlight" )
                                 $(elt).attr('class', "selected_article_highlight" )
                                 self.display_article_text {id: $(elt).attr("id"), all_text: $(elt).data("text")}
                                 overlay_loc = $(elt).data("loc")
                                 self.display_mask(overlay_loc)
                                 self.set_article_dataset_form $(elt).attr('id')
                                 history.replaceState(null, null, "##{$(elt).attr("id")}"); # url fragment
                             else
                                 $(elt).attr('class', "hover_article_highlight" )
                                 self.display_article_text null
                                 history.replaceState(null, null, ' '); # url fragment
                     enterHandler: (event)->
                         elt = event.eventSource.element
                         if $(elt).attr('class') != "selected_article_highlight"
                             $(elt).attr('class', "hover_article_highlight" )
                     exitHandler: (event)->
                         elt = event.eventSource.element
                         if $(elt).attr('class') != "selected_article_highlight"
                             $(elt).attr('class', "base_article_highlight" )
                 })
          )

    set_article_dataset_form: (article_id)->
        if article_id == null
            $("#article_dataset_panel").hide()
        else
            $("#article_dataset_panel input[name=\"doc_id\"]").attr('value', article_id)

            # datasets memberships
            API.get_datasets_with_doc article_id, (data)->
                if data.length > 0
                    datasets = $("<p style=\"font-style: italic;\">Currently belongs to: </p>")
                    for obj in data
                        relevancy_mapping = {0: ['dark', 'Not relevant'], 1: ['light', 'Somewhat relevant'], 2: ['info', 'Relevant'], 3: ['primary', 'Very relevant']}
                        badge_type = relevancy_mapping[obj[2]][0]
                        tooltip = relevancy_mapping[obj[2]][1]
                        a = $("<a href=\"/datasets/#{obj[0]}\"></a>")
                        span = $("<span class=\"dataset-#{obj[0]} badge badge-#{badge_type}\" title=\"#{tooltip}\" data-relevancy=\"#{obj[2]}\">#{obj[1]}</span>")
                        a.append span
                        datasets.append a
                    $("#article_in_datasets_list").html datasets[0].outerHTML
                else
                    $("#article_in_datasets_list").html ""

            $("#article_dataset_panel").show()


    display_mask: (overlay_loc)->
        self = @
        maskN = $("<div id=\"mask_north\" class=\"selection_mask\"></div>")
        maskE = $("<div id=\"mask_east\" class=\"selection_mask\"></div>")
        maskS = $("<div id=\"mask_south\" class=\"selection_mask\"></div>")
        maskW = $("<div id=\"mask_west\" class=\"selection_mask\"></div>")
        locN = new OpenSeadragon.Rect(0, 0, overlay_loc.x+overlay_loc.width, overlay_loc.y)
        locE = new OpenSeadragon.Rect(overlay_loc.x+overlay_loc.width, 0, self.viewer.viewport._contentBounds.width-(overlay_loc.x+overlay_loc.width), overlay_loc.y+overlay_loc.height)
        locS = new OpenSeadragon.Rect(overlay_loc.x, overlay_loc.y+overlay_loc.height, self.viewer.viewport._contentBounds.width-overlay_loc.x, self.viewer.viewport._contentBounds.height-(overlay_loc.y+overlay_loc.height))
        locW = new OpenSeadragon.Rect(0, overlay_loc.y, overlay_loc.x, self.viewer.viewport._contentBounds.height-overlay_loc.y)
        self.viewer.addOverlay {element: maskN[0], location: locN}
        self.viewer.addOverlay {element: maskE[0], location: locE}
        self.viewer.addOverlay {element: maskS[0], location: locS}
        self.viewer.addOverlay {element: maskW[0], location: locW}

    hide_mask: ->
        self = @
        self.viewer.removeOverlay maskN[0] unless maskN == null
        self.viewer.removeOverlay maskE[0] unless maskE == null
        self.viewer.removeOverlay maskS[0] unless maskS == null
        self.viewer.removeOverlay maskW[0] unless maskW == null

    display_article_text: (article)->
        if article == null
            $("#article_text").html ""
            $("#article_panel")[0].scrollTop = 0
            $("#article_panel").hide()
        else
            div = $("<div>")
            div.append $("<p><span style=\"color: #888888; font-weight: bold;\">ArticleID: </span>#{article.id}</p>")
            div.append $("<hr/>")
            div.append $("<p>#{article.all_text.replace(new RegExp("\\\\n", "g"), "<br/>").slice(1,-1)}</p>")
            $("#article_panel").show()
            $("#article_text").html div.html()
            $("#article_panel")[0].scrollTop = 0

    set_current_page: (page)->
        total_page = parseInt($("#total_page").text(), 10)
        $("span#current_page").text(page)
        if page == 1
            $("#page_previous").parent().prop("disabled", true )
        else
            $("#page_previous").parent().prop("disabled", false )
        if page == total_page
            $("#page_next").parent().prop("disabled", true )
        else
            $("#page_next").parent().prop("disabled", false )

