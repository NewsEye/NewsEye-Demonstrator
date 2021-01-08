class @DatasetsShow
    constructor: ->
        self = @
        console.log "datasets show specific"
        @default_per_page = 10
        @setup_controls()
        @load_documents 1, @default_per_page, @default_sort, @default_sort_order, ["article"], (data)->
            API.get_dataset_named_entities $('#div_dataset_id').text(), (data)->

        $("#export_zip_button").click (e)->
            DatasetsShow.post("/export_dataset/zipped", {id: $("#div_dataset_id").text() } )
        $("#export_csv_button").click (e)->
            DatasetsShow.post("/export_dataset/csv", {id: $("#div_dataset_id").text() } )
        $("#export_excel_button").click (e)->
            DatasetsShow.post("/export_dataset/excel", {id: $("#div_dataset_id").text() } )
        $("#export_json_button").click (e)->
            DatasetsShow.post("/export_dataset/json", {id: $("#div_dataset_id").text() } )

        if @urlParam("sort") == "date"
            if @urlParam("sort_order") == "desc"
                $($("#sort-dropdown button")[0]).html("Sort by date (⬆) <span class=\"caret\"></span>")
            else
                $($("#sort-dropdown button")[0]).html("Sort by date (⬇) <span class=\"caret\"></span>")
        if @urlParam("sort") == "relevancy"
            if @urlParam("sort_order") == "desc"
                $($("#sort-dropdown button")[0]).html("Sort by relevancy (⬆) <span class=\"caret\"></span>")
            else
                $($("#sort-dropdown button")[0]).html("Sort by relevancy (⬇) <span class=\"caret\"></span>")

        $('#apply_global_dataset_changes').click ->
            working_dataset_id = $('#div_dataset_id').text()
            $("#global_dataset_relevancy_form input[type='hidden']").remove() # Remove existing hidden fields
            hidden = $("<input type=\"hidden\" name=\"current_url\" value=\"#{window.location.href}\"></input>")
            $("#global_dataset_relevancy_form").append hidden
            for doc in $('div.document')
                if typeof($(doc).find('input:checked')[0]) != "undefined"
                    if $($(doc).find('h3 a')[0]).data('compound-id') == "undefined"
                        doc_id = $(doc).find('h3 a')[0]['href'].split('/').pop()
                    else # compound article case
                        doc_id = $($(doc).find('h3 a')[0]).data('compound-id')
                    relevancy = $($(doc).find("span.dataset-#{working_dataset_id}")[0]).data('relevancy')
                    relevancy = -1 if typeof relevancy == 'undefined'
                    hidden = $("<input type=\"hidden\" name=\"relevancy[#{doc_id}]\" value=\"#{relevancy}\"></input>")
                    $("#global_dataset_relevancy_form").append hidden

        $('.dataset_check').prop("checked", false)
        $('#select_all_checkbox').change (e)->
            if $('#select_all_checkbox').is(":checked")
                $('.dataset_check').prop("checked", true )
            else
                $('.dataset_check').prop("checked", false )

        $('#merge_datasets_form').submit ()->
            hidden = $("<input type=\"hidden\" name=\"current_url\" value=\"#{window.location.href}\"></input>")
            $("#merge_datasets_form").append hidden
#         The next thing is handled in the modal _merge_datasets.html.erb
#         $('#relevancy_radios input').change ()->
#             console.log("ok")

    setup_controls: ()->
        self = @
        $("#doctype_selectors button").on "click", (e)->
            unless $(e.currentTarget).hasClass "active"
                $(e.currentTarget).addClass "active"
                sort = $("#dataset_sort_select select option:selected").data("sort")
                sort_order = $("#dataset_sort_select select option:selected").data("order")
                $("#doctype_selectors button[id!='#{e.currentTarget.id}']").removeClass "active"
                $("#dataset_documents_list").html("<div id=\"spinner\" style=\"margin: auto;\"></div>")
                self.load_documents 1, self.default_per_page, sort, sort_order, [$(e.currentTarget).data("doctype")], undefined

        $("#dataset_pagination").on "click", "button", (e)->
            doctype = $($("#doctype_selectors button.active")[0]).data("doctype")
            current_page = parseInt($("#dataset_pagination button.active").text())
            sort = $("#dataset_sort_select select option:selected").data("sort")
            sort_order = $("#dataset_sort_select select option:selected").data("order")
            if $(e.target).data("action") == "prev"
                $("#dataset_documents_list").html("<div id=\"spinner\" style=\"margin: auto;\"></div>")
                self.load_documents current_page-1, self.default_per_page, sort, sort_order, [doctype], undefined
            else if $(e.target).data("action") == "next"
                $("#dataset_documents_list").html("<div id=\"spinner\" style=\"margin: auto;\"></div>")
                self.load_documents current_page+1, self.default_per_page, sort, sort_order, [doctype], undefined
            else if $(e.target).data("action") == "page"
                target_page = parseInt($(e.target).text())
                $("#dataset_documents_list").html("<div id=\"spinner\" style=\"margin: auto;\"></div>")
                self.load_documents target_page, self.default_per_page, sort, sort_order, [doctype], undefined
            return false
        $("#dataset_sort_select select").on "change", (e)->
            doctype = $($("#doctype_selectors button.active")[0]).data("doctype")
            current_page = parseInt($("#dataset_pagination button.active").text())
            $("#dataset_documents_list").html("<div id=\"spinner\" style=\"margin: auto;\"></div>")
            sort = $(e.target.selectedOptions[0]).data("sort")
            sort_order = $(e.target.selectedOptions[0]).data("order")
            self.load_documents current_page, self.default_per_page, sort, sort_order, [doctype], undefined


    load_documents: (page, per_page, sort, sort_order, type, callback)->
        API.paginate_dataset $("#div_dataset_id").text(), page, per_page, sort, sort_order, type, (data)->
            if callback
                callback(data)


    urlParam: (name)->
        results = new RegExp('[\?&]' + name + '=([^&#]*)').exec(window.location.href)
        if results==null
           return null
        else
           return results[1] || 0

#     /**
#      * sends a request to the specified url from a form. this will change the window location.
#      * @param {string} path the path to send the post request to
#      * @param {object} params the paramiters to add to the url
#      * @param {string} [method=post] the method to use on the form
#      */

    @post: (path, params, method='post')->
        #       // The rest of this code assumes you are not using a library.
        #       // It can be made less wordy if you use one.
        form = document.createElement('form')
        form.method = method
        form.action = path
        for key of params
            #if params.hasOwnProperty(key)
            hiddenField = document.createElement('input')
            hiddenField.type = 'hidden'
            hiddenField.name = key
            hiddenField.value = params[key]
            form.appendChild(hiddenField)

        document.body.appendChild(form)
        form.submit()