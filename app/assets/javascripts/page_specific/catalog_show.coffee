class @CatalogShow

    maskN = null
    maskE = null
    maskS = null
    maskW = null
    isDragged = false
    compoundMode = false
    compoundArticleParts = []

    constructor: ->
        self = @
        console.log 'show'
        @setup_select()
        @setup_compound()
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
             tileSources: pages_urls,
#             nextButton:     "page_next",
#             previousButton: "page_previous"
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
             self.set_named_entities [article_id]
             pagenum = self.viewer.currentPage()
             $("#current_page").html("#{pagenum+1}")
             selected_compound_article = $("#existing_compound_list li.active").data('parts')
             for article in articles[pagenum+1]
                 bbox = article['bbox']
                 loc = self.viewer.viewport.imageToViewportRectangle(bbox[0], bbox[1], bbox[2], bbox[3])
                 if article_id == article.id
                    article_class =  "selected_article_highlight"
                    self.display_mask(loc)
                    self.display_article_text article
                    self.viewer.viewport.zoomTo(2)
                    self.viewer.viewport.panTo(new OpenSeadragon.Point(loc.x+loc.width/2, loc.y+loc.height/2))
                    self.set_article_dataset_form(article_id)
                 else
                    array_elt = compoundArticleParts.filter (x)-> x.id == article.id
                    if array_elt.length == 0
                        if selected_compound_article and article.id in selected_compound_article
                            article_class =  "selected_compound_article_highlight"
                            if article.id == selected_compound_article[0]
                                self.viewer.viewport.zoomTo(2)
                                self.viewer.viewport.panTo(new OpenSeadragon.Point(loc.x+loc.width/2, loc.y+loc.height/2))
                        else
                            article_class =  "base_article_highlight"
                    else
                        article_class =  "compound_article_highlight"
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
                         selected_compound_article = $("#existing_compound_list li.active").data('parts')
                         elt = event.eventSource.element
                         if $(elt).attr('data-noclick') != undefined
                             $(elt).removeAttr('data-noclick')
                         else
                             if compoundMode
                                 array_elt = compoundArticleParts.filter (x)-> x.id == elt.id
                                 if array_elt.length == 0  # Add a new textblock to the compound list
                                     compoundArticleParts.push {id: elt.id, text: $(elt).data("text")}
                                     list_elt = $("<li data-id=\"#{elt.id}\" class=\"list-group-item\"></li>")
                                     text = $("<div class=\"text_part\" style=\"display: inline;\">#{$(elt).data("text").slice(1,-1).substring(0,37)}...</div>")
                                     delete_span = $("<a class=\"delete_article_part\"><span class=\"glyphicon glyphicon-remove\" style=\"color: red\"></span></a>")
                                     move_span = $("<span class=\"glyphicon glyphicon-menu-hamburger li-handle\" style=\"color: black\"></span>")
                                     list_elt.append move_span
                                     list_elt.append text
                                     list_elt.append delete_span
                                     $("#compound_list").append list_elt
                             else
                                 self.hide_mask()
                                 self.set_article_dataset_form null
                                 # one overlay can be selected at a time
                                 if $(elt).hasClass("selected_article_highlight")  # unselect article
                                     $(elt).removeClass("selected_article_highlight" )
                                     $(elt).addClass("hover_article_highlight" )
                                     self.display_article_text null
                                     history.replaceState(null, null, ' '); # url fragment
                                     self.set_named_entities []
                                 else  # select article
                                     for e in $(".selected_article_highlight")
                                         array_elt = compoundArticleParts.filter (x)-> x.id == e.id
                                         if array_elt.length == 0
                                             if selected_compound_article and e.id in selected_compound_article
                                                 $(e).attr('class', "selected_compound_article_highlight")
                                             else
                                                 $(e).attr('class', "base_article_highlight" )
                                         else
                                             $(e).attr('class', "compound_article_highlight" )
                                     $(elt).attr('class', "selected_article_highlight" )
                                     self.display_article_text {id: $(elt).attr("id"), all_text: $(elt).data("text").slice(1,-1)}
                                     overlay_loc = $(elt).data("loc")
                                     self.display_mask(overlay_loc)
                                     self.set_article_dataset_form $(elt).attr('id')
                                     history.replaceState(null, null, "##{$(elt).attr("id")}"); # url fragment
                                     self.set_named_entities [$(elt).attr("id")]
                     enterHandler: (event)->
                         elt = event.eventSource.element
                         if $(elt).attr('class') != "selected_article_highlight"
                             $(elt).attr('class', "hover_article_highlight" )
                     exitHandler: (event)->
                         selected_compound_article = $("#existing_compound_list li.active").data('parts')
                         elt = event.eventSource.element
                         if $(elt).attr('class') != "selected_article_highlight"
                             array_elt = compoundArticleParts.filter (x)-> x.id == elt.id
                             if array_elt.length == 0
                                 if selected_compound_article and elt.id in selected_compound_article
                                     $(elt).attr('class', "selected_compound_article_highlight")
                                 else
                                     $(elt).attr('class', "base_article_highlight" )
                             else
                                $(elt).attr('class', "compound_article_highlight" )
                 })
          )

    setup_compound: ->
        self = @
        articles = $('#openseadragon_view').data("articles")
        $("#compoundMode").change (e)->
            self.set_named_entities []
            self.hide_mask()
            self.set_article_dataset_form null
            $("div.selected_article_highlight").attr('class', "base_article_highlight" )
            $("div.compound_article_highlight").attr('class', "base_article_highlight" )
            $("div.selected_compound_article_highlight").attr('class', "base_article_highlight" )
            $("#existing_compound_list li.active").removeClass 'active'
            self.display_article_text null
            history.replaceState(null, null, ' '); # url fragment
            compoundMode = e.currentTarget.checked
            $("#compound_list").html("")
            compoundArticleParts = []
            if compoundMode
                $("#compound_article_panel div hr").show()
                $("#compound_list").show()
                $("#help_compound").show()
                $("#create_compound_button").show()
            else
                $("#compound_article_panel div hr").hide()
                $("#compound_list").hide()
                $("#help_compound").hide()
                $("#create_compound_button").hide()

        sortable = Sortable.create($("#compound_list")[0],{
            animation: 150
            ghostClass: 'blue-background-class' # Set up correct CSS !!!!!!!
            onSort: (e)->
                ids = $.map e.target.children, (elt)->
                    return $(elt).data('id')
                compoundArticleParts.sort (a,b)->
                    return ids.indexOf(a.id) - ids.indexOf(b.id)
            handle: ".li-handle"
        })

        $("#compound_list").on "mouseenter", "li", (e)->
            article_id = $(e.currentTarget).data("id")
            $("##{article_id}").attr('class', "hover_article_highlight" )

        $("#compound_list").on "mouseleave", "li", (e)->
            article_id = $(e.currentTarget).data("id")
            array_elt = compoundArticleParts.filter (x)-> x.id == article_id
            if array_elt.length == 0
                $("##{article_id}").attr('class', "base_article_highlight" )
            else
                $("##{article_id}").attr('class', "compound_article_highlight" )

        $("#compound_list").on "click", "div.text_part", (e)->
            article_id = $(e.currentTarget.parentElement).data("id")
#            for pagenum, parts of articles
#                for part in parts
#                    if

        $("#compound_list").on "click", "a.delete_article_part", (e)->
            article_id = $(e.currentTarget.parentElement).data("id")
            for i in [0...compoundArticleParts.length]
                if compoundArticleParts[i].id == article_id
                    $(e.currentTarget.parentElement).remove()
                    compoundArticleParts.splice(i,1)
                    $("##{article_id}").attr('class', "base_article_highlight" )
                    break
        $("#compound_article_panel").on "click", "#create_compound_button", (e)->
            article_id = compoundArticleParts[0].id
            $.ajax {
                url:  window.location.protocol+"//"+window.location.host+'/confirm_compound_article',
                method: 'POST',
                data: {issue_id: article_id.substr(0, article_id.indexOf("_article_")), article_parts: compoundArticleParts}
            }

        $("body").on "click", "#create_compound_form_button", (e)->
            title = $(e.currentTarget).parent().find("input[type='text']")[0].value
            $("#compound_log").show()
            $("#compound_log").css("font-weight", "bold")
            if title.match /^.*[0-9a-z].*$/
                Rails.fire($('#create_compound_article_form')[0], 'submit')
            else
                $("#compound_log").css("color", "red")
                $("#compound_log").text "The title must contain at least one alphanumeric character."
                e.preventDefault()

        $("#existing_compound_list").on "click", "a.delete_compound", (e)->
            compound_id = $(e.currentTarget.parentElement).data('id')
            API.delete_compound_article compound_id, (data)->
                if data['message'] == "ok"
                    e.currentTarget.parentElement.remove()
                if $("#existing_compound_list li").length == 0
                    $("#existing_compound_list").hide()
            e.stopPropagation()

        $("#existing_compound_list").on "click", "li", (e)->
            others = $("div.selected_compound_article_highlight")
            others.removeClass("selected_compound_article_highlight")
            others.addClass("base_article_highlight")
            if $(e.currentTarget).hasClass "active"
                $(e.currentTarget).removeClass "active"
                self.set_compound_article_dataset_form null, null
                self.set_named_entities []
            else
                $(e.currentTarget.parentElement).find("li").removeClass 'active'
                $(e.currentTarget).addClass "active"

                compound_id = $(e.currentTarget).data('id')
                compound_title = $(e.currentTarget).find("div.compound_title").text()
                self.set_compound_article_dataset_form compound_id, compound_title
                parts_ids = $(e.currentTarget).data('parts')
                self.set_named_entities parts_ids
                compound_page = -1
                for pagenum, parts of articles
                    for part in parts
                        if part.id == parts_ids[0]
                            compound_page = pagenum
                            break
                    break if compound_page != -1
                if compound_page != -1 # if page of article was found
                    if self.viewer.currentPage() != compound_page-1
                        self.viewer.goToPage(compound_page-1)
                    else
                        part = articles[compound_page].filter( (p)-> p.id == parts_ids[0] )
                        if part.length != 0
                            bbox = part[0]['bbox']
                            loc = self.viewer.viewport.imageToViewportRectangle(bbox[0], bbox[1], bbox[2], bbox[3])
                            self.viewer.viewport.zoomTo(2)
                            self.viewer.viewport.panTo(new OpenSeadragon.Point(loc.x+loc.width/2, loc.y+loc.height/2))
                        for part_id in parts_ids
                            $("##{part_id}").addClass("selected_compound_article_highlight")



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

    set_compound_article_dataset_form: (compound_id, compound_title)->
        $('#compound_article_dataset_panel form').off "submit"
        $('#compound_article_dataset_panel form').submit ->
            return confirm("This will remove parts of this compound article from your dataset and add the compound. Proceed ?")
        if compound_id == null
            $("#compound_article_dataset_panel").hide()
        else
            $("#compound_article_dataset_panel input[name=\"doc_id\"]").attr('value', compound_id)
            $("#compound_article_dataset_panel input[name=\"compound_title\"]").attr('value', compound_title)
            # datasets memberships
            API.get_datasets_with_doc compound_id, (data)->
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
                    $("#compound_article_in_datasets_list").html datasets[0].outerHTML
                else
                    $("#compound_article_in_datasets_list").html ""

            $("#compound_article_dataset_panel").show()



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
            div.append $("<p>#{article.all_text.replace(new RegExp("\\\\n", "g"), "<br/>")}</p>")
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

    load_named_entities_panels: ->
        API.update_named_entities_panels JSON.stringify($("#named_entities").data('ne')), (data)->
            $("#named_entities").html(data.responseText)
            $("#named_entities").show()

    set_named_entities: (selected_articles_ids)->
        selected_articles_ids = selected_articles_ids.filter( (el)-> el != null )
        mapping = {"PER": "Persons", "LOC": "Locations", "ORG": "Organizations", "HumanProd": "Human Productions"}
        stance_mapping = {'-1': '-', '0': '=', '1': '+'}
        to_display = {}
        named_entities = $("#named_entities").data('ne')
        if selected_articles_ids.length == 0
            to_display = named_entities
        else
            for ne_type of named_entities
                for linked of named_entities[ne_type]
                    for mention in named_entities[ne_type][linked]
                        if selected_articles_ids.includes(mention['article_id_ssi'])
                            to_display[ne_type] ||= {}
                            to_display[ne_type][linked] ||= []
                            to_display[ne_type][linked].push mention
        API.get_named_entities_kburl_label Object.keys(to_display).map( (k)-> Object.keys(to_display[k]) ).flat(), (named_entities_infos)->
            named_entities_infos = named_entities_infos.responseJSON
            $("#named_entities").html("")
            for ne_type of to_display
                panel = $('<div class="panel panel-default"></div>')
                panel_heading = $('<div class="panel-heading"></div>')
                panel_title = $('<h4 class="panel-title"></h4>')
                a = $('<a data-toggle="collapse" href="#entities_' + ne_type + '">')
                a.append document.createTextNode(mapping[ne_type])
                span = $('<span style="color: grey"></span>')
                nb = Object.values(to_display[ne_type]).reduce( (acc,val,i,a)->
                    return acc+val.length
                , 0)
                content = '(' + Object.keys(to_display[ne_type]).length + ' entities, ' + nb + ' mentions)'
                span.append document.createTextNode(content)
                a.append span
                panel_title.append a
                panel_heading.append panel_title
                panel.append panel_heading

                panel_content = $('<div id="entities_' + ne_type + '" class="panel-collapse collapse">')
                ul = $('<ul class="list-group"></ul>')
                for linked in Object.keys(to_display[ne_type]).sort( (a,b)-> return to_display[ne_type][a].length < to_display[ne_type][b].length )
                    if to_display[ne_type][linked]
                        li = $('<li class="list-group-item"></li>')
                        if linked == ""
                            entity_label = "Unlinked #{mapping[ne_type]}"
                        else
                            if named_entities_infos[linked]
                                entity_label = named_entities_infos[linked]['label']
                            else
                                entity_label = ""  # when linked not indexed in solr
                        linked_a = $('<a data-toggle="collapse" href="#entities_' + ne_type + '_' + linked + '">'+entity_label+'</a>')
                        text = document.createTextNode(" (#{to_display[ne_type][linked].length} mention#{if to_display[ne_type][linked].length > 1 then "s" else ""})")
                        li.append linked_a
                        li.append text
                        if named_entities_infos[linked]
                            kb_link = $('<a class="pull-right" target="_blank" href="' + named_entities_infos[linked]['url'] + '"><span class="glyphicon glyphicon-info-sign" style="color: black"></span></a>')
                            li.append kb_link
                        mentions = $('<div id="entities_' + ne_type + '_' + linked + '" class="panel-collapse collapse">')
                        mentions_list = $('<ul class="list-group"></ul>')
                        for ne in to_display[ne_type][linked]
                            li2 = $('<li class="list-group-item ne_mention"></li>')
                            li2.append document.createTextNode("#{ne['mention_ssi']} (#{stance_mapping[ne['stance_fsi']]})")
                            mentions_list.append li2
                        mentions.append mentions_list
                        ul.append li
                        ul.append mentions
                panel_content.append ul
                panel.append panel_content
                $("#named_entities").append panel
                # console.log panel