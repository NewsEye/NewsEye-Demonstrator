class @CatalogIndex
    constructor: ->
        self = @
        console.log 'index'
        @setup_select()

        $('#apply_global_dataset_changes').click ->
            working_dataset_id = $('#working_dataset_select').children('option:selected')[0].value
            $("#global_dataset_relevancy_form input[type='hidden']").remove() # Remove existing hidden fields
            hidden = $("<input type=\"hidden\" name=\"current_url\" value=\"#{window.location.href}\"></input>")
            $("#global_dataset_relevancy_form").append hidden
            for doc in $('div.document')
                if typeof($(doc).find('input:checked')[0]) != "undefined"
                    doc_id = $(doc).find('h3 a')[0]['href'].split('/').pop()
                    relevancy = $($(doc).find("span.dataset-#{working_dataset_id}")[0]).data('relevancy')
                    relevancy = -1 if typeof relevancy == 'undefined'
                    hidden = $("<input type=\"hidden\" name=\"relevancy[#{doc_id}]\" value=\"#{relevancy}\"></input>")
                    $("#global_dataset_relevancy_form").append hidden

        $(window).scroll (e)->
            # Get the position of the location where the scroller starts.
            scroller_anchor = $(".scroller_anchor").offset().top
            #Check if the user has scrolled and the current position is after the scroller start location and if its not already fixed at the top
            if $(this).scrollTop() >= scroller_anchor && $('#dataset_handling_div').css('position') != 'fixed'
            # Change the CSS of the scroller to hilight it and fix it at the top of the screen.
                $('#dataset_handling_div').css {
                    'position': 'fixed',
                    'top': '0px'
                }
            # Changing the height of the scroller anchor to that of scroller so that there is no change in the overall height of the page.
                $('.scroller_anchor').css('height', '50px')
            else if $(this).scrollTop() < scroller_anchor && $('#dataset_handling_div').css('position') != 'relative'
            # If the user has scrolled back to the location above the scroller anchor place it back into the content.

                # Change the height of the scroller anchor to 0 and now we will be adding the scroller back to the content.
                $('.scroller_anchor').css('height', '0px')

                # Change the CSS and put it back to its original position.
                $('#dataset_handling_div').css {
                    'position': 'relative'
                }

        $('.dataset_check').prop("checked", false )

        $('#select_all_checkbox').change (e)->
            if $('#select_all_checkbox').is(":checked")
                $('.dataset_check').prop("checked", true )
            else
                $('.dataset_check').prop("checked", false )


    setup_select: ->
        self = @
        $("#working_dataset_select").change ->
            Rails.fire($('#working_dataset_select').parent()[0], 'submit')