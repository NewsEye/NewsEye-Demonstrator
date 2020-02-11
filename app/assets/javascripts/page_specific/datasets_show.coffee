class @DatasetsShow
    constructor: ->
        console.log "datasets show specific"

        $("#zip_export_anchor").click (e)->
            $('#export_form').attr 'action', "/export_dataset/zipped"
            Rails.fire $('#export_form')[0], 'submit'
        $("#csv_export_anchor").click (e)->
            $('#export_form').attr 'action', "/export_dataset/csv"
            Rails.fire $('#export_form')[0], 'submit'
        $("#json_export_anchor").click (e)->
            $('#export_form').attr 'action', "/export_dataset/json"
            Rails.fire $('#export_form')[0], 'submit'

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
            $("#global_dataset_relevancy_form input[type='hidden']").remove() # Remove existing hidden fields
            hidden = $("<input type=\"hidden\" name=\"current_url\" value=\"#{window.location.href}\"></input>")
            $("#global_dataset_relevancy_form").append hidden
            for doc in $('div.document')
                if typeof($(doc).find('input:checked')[0]) != "undefined"
                    doc_id = $(doc).find('h3 a')[0]['href'].split('/').pop()
                    relevancy = $($(doc).find("dd.relevancy_value")[0]).data('relevancy')
                    relevancy = -1 if typeof relevancy == 'undefined'
                    hidden = $("<input type=\"hidden\" name=\"relevancy[#{doc_id}]\" value=\"#{relevancy}\"></input>")
                    $("#global_dataset_relevancy_form").append hidden

        $('.dataset_check').prop("checked", false)
        $('#select_all_checkbox').change (e)->
            if $('#select_all_checkbox').is(":checked")
                $('.dataset_check').prop("checked", true )
            else
                $('.dataset_check').prop("checked", false )

    urlParam: (name)->
        results = new RegExp('[\?&]' + name + '=([^&#]*)').exec(window.location.href)
        if results==null
           return null
        else
           return results[1] || 0