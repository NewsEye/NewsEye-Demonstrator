class @CatalogIndex

    @big_chart: null

    constructor: ->
        self = @
        console.log 'index'
        @setup_select()
        @setup_search_field()
        @setup_date_facet()
        @setup_date_histogram()
        @setup_wide_date_histogram()
        @setup_add_all_docs_to_dataset()

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
            if $(".scroller_anchor").offset()
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

    setup_search_field: ->
        self = @
        urlParams = new URLSearchParams(window.location.search)
        val = urlParams.get("search_field")
        $("#search_field").val(val) unless val == null

    setup_date_facet: ->
        self = @
        min_year = $("#min_date_facet").data("year")
        max_year = $("#max_date_facet").data("year")
        min_date_facet = new Date(
            $("#min_date_facet").data("year"),
            $("#min_date_facet").data("month"),
            $("#min_date_facet").data("day")
        )
        max_date_facet = new Date(
            $("#max_date_facet").data("year"),
            $("#max_date_facet").data("month"),
            $("#max_date_facet").data("day")
        )
        params = new URLSearchParams(window.location.search);
        current_from_date = params.get("f[date_created_dtsi][from]")
        current_to_date = params.get("f[date_created_dtsi][to]")
        if current_from_date
            $("#date_facet_from").val(current_from_date)
            current_from_date = $.datepicker.parseDate("dd/mm/yy", current_from_date)
        else
            current_from_date = min_date_facet
        if current_to_date
            $("#date_facet_to").val(current_to_date)
            current_to_date = $.datepicker.parseDate("dd/mm/yy", current_to_date)
        else
            current_to_date = max_date_facet

        $.datepicker.setDefaults {
            changeMonth: true,
            changeYear: true,
            dateFormat: "dd/mm/yy"
        }
        date_from = $("#date_facet_from").datepicker {
            onSelect: (dateText, instance)->
                $("#date_facet_to").datepicker("option", "minDate", dateText)
            yearRange: "#{min_year}:#{max_year}"
            minDate: min_date_facet
            maxDate: max_date_facet
            defaultDate: current_from_date
        }
        date_to = $("#date_facet_to").datepicker {
            onSelect: (dateText, instance)->
                $("#date_facet_from").datepicker("option", "maxDate", dateText)
            yearRange: "#{min_year}:#{max_year}"
            minDate: min_date_facet
            maxDate: max_date_facet
            defaultDate: current_to_date
        }
        $("#date_pickers form").submit ()->
            $(this).find(":input").filter( ()->
                return !this.value
            ).attr("disabled", "disabled")
            return true
        $("#date_pickers form").find(":input").prop("disabled", false)

    setup_date_histogram: ->
        data = $("#dates_histogram").data("years")
        labels = []
        values = []
        for key of data
            labels.push key
            values.push data[key]
        dataset = {}
        dataset['label'] = "Date frequencies"
        dataset['backgroundColor'] = 'rgba(0, 0, 0, 0.1)'
        dataset['borderColor'] =  'rgba(0, 0, 0, 0.5)'
        dataset['lineTension'] = 0.4
        dataset['fill'] = 'origin'
        dataset['borderWidth'] = 1
        dataset['hidden'] = false
        dataset['data'] = values
        ctx = $("#canvas_dates_histogram")
        opts = {
            responsive: true,
            maintainAspectRatio: false,
            legend: {
                display: false
            },
            tooltips:{
                enabled: false
            },
            scales: {
                yAxes: [{
                    ticks: {
                        beginAtZero: true
                    }
                }]
            }
        }
        chart = new Chart(ctx, {
           type: 'bar',
           data: {
               labels: labels,
               datasets: [dataset]
           },
           options: opts
        })
        return chart

    setup_wide_date_histogram: ->
        self = @
#         data = $("#dates_histogram").data("years-months")
        data = $("#dates_histogram").data("years")
        $("#modal-wide_date_histogram").on "shown.bs.modal", (e)->
            self.generate_chart(data)

            $("#download_histogram").click (e)->
                b64data = $("#canvas_wide_dates_histogram")[0].toDataURL()
                $("#download_histogram").attr('href', b64data)
            $("#reset_zoom_histogram").click {canvas_id: "canvas_wide_dates_histogram" }, (e)->
                Chart.helpers.each Chart.instances, (instance)->
                    if instance.chart.canvas.id == e.data.canvas_id
                        instance.chart.resetZoom()
            $("#hist_type input[type=radio]").on 'change', (e)->
                if @.value == "year"
                    data = $("#dates_histogram").data("years")
                    self.generate_chart(data)
                if @.value == "month"
                    data = $("#dates_histogram").data("years-months")
                    self.generate_chart(data)

    generate_chart: (data)->
        CatalogIndex.big_chart.destroy() if CatalogIndex.big_chart?
        labels = []
        values = []
        keys = Object.keys(data).sort()
        for key in keys
            labels.push key
            values.push data[key]
        dataset = {}
        dataset['label'] = "Date frequencies"
        dataset['backgroundColor'] = 'rgba(0, 0, 0, 0.1)'
        dataset['borderColor'] =  'rgba(0, 0, 0, 0.5)'
        dataset['lineTension'] = 0.4
        dataset['fill'] = 'origin'
        dataset['borderWidth'] = 1
        dataset['hidden'] = false
        dataset['data'] = values
        ctx = $("#canvas_wide_dates_histogram")
        opts = {
            responsive: true,
            maintainAspectRatio: false,
            legend: {
                display: false
            },
            tooltips:{
                enabled: false
            },
            scales: {
                yAxes: [{
                    ticks: {
                        beginAtZero: true
                    }
                }]
            },
            plugins: {
                zoom: {
                    pan: {
                        enabled: true,
                        mode: 'x'
                    },
                    zoom: {
                        enabled: true,
                        mode: 'x',
                        sensitivity: 0,
                        speed: 1
                    }
                }
            }
        }
        CatalogIndex.big_chart = new Chart(ctx, {
           type: 'bar',
           data: {
               labels: labels,
               datasets: [dataset]
           },
           options: opts
        })

    setup_add_all_docs_to_dataset: ->
        $("#modal-add_all_docs").on "shown.bs.modal", (e)->
            $("#validate_add_all_docs").click (e)->
                $("#validate_add_all_docs")[0].disabled = true
                $("#log_add_docs").text("Processing...")
                dataset_id = $("#add_docs_dataset_select").val()
                relevancy = $("#add_docs_dataset_relevancy_select").val()
                query_params = JSON.parse($("#query_params").html())
                total_docs = $("#query_total_res").html()
                query_params["fl"] = 'id'
                query_params["rows"] = 100
                query_params["start"] = 0

                numberOfIterations = Math.ceil(total_docs/query_params["rows"])
                async_loop = (q_params, i)->
                    API.add_query_to_dataset JSON.stringify(q_params), dataset_id, relevancy, (data)->
                        $("#log_add_docs").text(data["message"])
                        if i+1 < numberOfIterations
                            q_params["start"] = q_params["start"] + q_params["rows"]
                            async_loop(q_params, i+1)
                        else
                            $("#validate_add_all_docs")[0].disabled = false
                async_loop(query_params, 0)

    setup_select: ->
        self = @
        $("#working_dataset_select").change ->
            Rails.fire($('#working_dataset_select').parent()[0], 'submit')