class @PRAUtils
    @generate_results_modal: (node)->
        html_code1 = [
            "<div>",
            "    <div class='modal-header'>",
            "        <button type='button' class='close' data-dismiss='modal'>x</button>",
            "        <h4 class='modal-title'>Results for #{node.data('type')}</h4>",
            "    </div>",
            "    <div class='modal-body'>",
            "        <h4>Report</h4>",
            "        <div id='div_modal_report'><div id='spinner'></div></div>",
            "        <h4>Results</h4>",
            "        <div id='div_modal_results'><div id='spinner'></div></div>",
            "    </div>",
            "</div>"
        ]
        return html_code1.join("")

    @generate_parameters_modal: ->
        return ""

    @create_canvases: (data)->
        canvases = []
        if data.processor == "ExtractFacets"
            for facet of data.task_result.result
                $("#modal-results").off "click", "button#reset_zoom_canvas_#{data['uuid']}_#{facet}"
                $("#modal-results").on "click", "button#reset_zoom_canvas_#{data['uuid']}_#{facet}", {canvas_id: "canvas_#{data['uuid']}_#{facet}"}, (event)->
                    Chart.helpers.each Chart.instances, (instance)->
                        if instance.chart.canvas.id == event.data.canvas_id
                            instance.chart.resetZoom()
                    event.preventDefault()
                    return false
                canvases.push $("<button id='reset_zoom_canvas_#{data['uuid']}_#{facet}'>Reset zoom</button>")
                canvases.push $("<canvas id='canvas_#{data['uuid']}_#{facet}' style='height: 200px; width: 700px;'></canvas>")
        if data.processor == "GenerateTimeSeries"
            for ts of data.task_result.result
                $("#modal-results").off "click", "button#reset_zoom_canvas_#{data['uuid']}_#{facet}"
                $("#modal-results").on "click", "button#reset_zoom_canvas_#{data['uuid']}_#{facet}", {canvas_id: "canvas_#{data['uuid']}_#{facet}"}, (event)->
                    Chart.helpers.each Chart.instances, (instance)->
                        if instance.chart.canvas.id == event.data.canvas_id
                            instance.chart.resetZoom()
                    event.preventDefault()
                    return false
                canvases.push $("<canvas id='canvas_#{data['uuid']}_#{ts}' style='height: 200px; width: 700px;'></canvas>")
        if data.processor == "ExtractWords"
            canvases.push $("<canvas id='canvas_#{data['uuid']}' style='height: 200px; width: 700px;'></canvas>")
        if data.processor == "ExtractBigrams"
            canvases.push $("<canvas id='canvas_#{data['uuid']}' style='height: 200px; width: 700px;'></canvas>")
        if data.processor == "Summarization"
            canvases.push $("<canvas id='canvas_#{data['uuid']}' style='height: 200px; width: 700px;'></canvas>")
        if data.processor == "ExtractNames"
            canvases.push $("<canvas id='canvas_#{data['task_uuid']}' style='height: 200px; width: 700px;'></canvas>")
        return canvases

    @populate_canvases: (data)->
        if data.processor == "GenerateTimeSeries"
            PRAUtils.generate_time_series_results data
        if data.processor == "ExtractFacets"
            PRAUtils.extract_facets_results data
        if data.processor == "ExtractWords"
            PRAUtils.extract_words_results data
        if data.processor == "ExtractBigrams"
            PRAUtils.extract_bigrams_results data
        if data.processor == "Summarization"
            PRAUtils.extract_summarization_results data
        if data.processor == "ExtractNames"
            PRAUtils.extract_names_results data
        if data.processor == "TrackNameSentiment"
            PRAUtils.extract_tracknamesentiment_results data

    @extract_tracknamesentiment_results: (data)->
        content = $("<div></div>")
        select = $("<select id=\"stance_ne_selector\"></select>")
        select.append $("<option selected disabled value=\"default\">Choose an entry...</option>")
        for name of data.task_result.images
            select.append $("<option value=\"#{name}\">#{name}</option>")
        content.append select
        content.append $("<div id=\"bar_chart\"></div>")
        content.append $("<div id=\"line_chart\"></div>")

        $("#div_modal_results").on "change", "#stance_ne_selector", {imgs: data.task_result.images}, (e)->
            console.log e
            name = e.currentTarget.value
            bar_base64 = e.data.imgs[name]['bar']
            $("#bar_chart").html $("<img src=\"data:image/png;base64, #{bar_base64}\"/>")[0].outerHTML
            line_base64 = e.data.imgs[name]['line']
            $("#line_chart").html $("<img src=\"data:image/png;base64, #{line_base64}\"/>")[0].outerHTML

        $("#div_modal_results").html content.html()

    @extract_names_results: (data)->
        API.get_locale (l)->
            locale = l.responseJSON[0]
            colors = PRAUtils.generate_colors(2, "80")
            colors_opaq = PRAUtils.generate_colors(2, "FF")
            datasets = []
            labels = []
            dataset1 = {}
            dataset1['label'] = "Named entities saliency"
            dataset1['yAxisID'] = "saliency"
            dataset1['backgroundColor'] =  colors[0]
            dataset1['borderColor'] =  colors_opaq[0]
            dataset1['lineTension'] = 0.4
            dataset1['fill'] = 'origin'
            dataset1['borderWidth'] = 1
            dataset1['hidden'] = false
            values1 = []
            dataset2 = {}
            dataset2['label'] = "Named entities stance"
            dataset2['type'] = "line"
            dataset2['cubicInterpolationMode'] = "monotone"
            dataset2['yAxisID'] = "stance"
            dataset2['backgroundColor'] =  colors[1]
            dataset2['borderColor'] =  colors_opaq[1]
            dataset2['lineTension'] = 1
            dataset2['fill'] = 'origin'
            dataset2['borderWidth'] = 1
            dataset2['hidden'] = false
            values2 = []
            for name of data.task_result.result
                if data.task_result.result[name]["names"]
                    labels.push data.task_result.result[name]["names"][locale]
                else
                    labels.push name
                values1.push data.task_result.result[name]["salience"]
                values2.push data.task_result.result[name]["stance"]
            dataset1['data'] = values1
            dataset2['data'] = values2
            datasets.push dataset1
            datasets.push dataset2
            PRAUtils.build_graph("canvas_#{data['task_uuid']}", labels, datasets, 'bar', multiple_dataset_select=false, multiple_axes=true)

    @extract_summarization_results: (data)->
        content = $("<div></div>")
        for part in data.task_result.result.summary
            content.append $("<p>#{part}</p>")
        $("#div_modal_results").html content.html()

    @extract_facets_results: (data)->
        for facet of data.task_result.result
            # If the canvas exists
            if $("#canvas_#{data['uuid']}_#{facet}").length
                colors = PRAUtils.generate_colors(1, "80")
                colors_opaq = PRAUtils.generate_colors(1, "FF")
                datasets = []
                labels = []
                dataset = {}
                dataset['label'] = facet
                dataset['backgroundColor'] =  colors[0]
                dataset['borderColor'] =  colors_opaq[0]
                dataset['lineTension'] = 0.4
                dataset['fill'] = 'origin'
                dataset['borderWidth'] = 1
                dataset['hidden'] = false
                values = []
                for point of data.task_result.result[facet]
                    labels.push point
                    values.push data.task_result.result[facet][point]
                dataset['data'] = values
                datasets.push dataset
                if facet == "PUB_YEAR"
                    PRAUtils.build_graph("canvas_#{data['uuid']}_#{facet}", labels, datasets, 'line')
                else
                    PRAUtils.build_graph("canvas_#{data['uuid']}_#{facet}", labels, datasets, 'bar')

    @generate_time_series_results: (data)->
        for ts of data.task_result.result
            datasets = []
            colors = PRAUtils.generate_colors(Object.keys(data.task_result.result[ts]).length, "80") # alpha in hex
            colors_opaq = PRAUtils.generate_colors(Object.keys(data.task_result.result[ts]).length, "FF") # alpha in hex
            color_idx = 0
            for entry of data.task_result.result[ts]
                labels = []
                dataset = {}
                dataset['label'] = entry
                dataset['backgroundColor'] =  colors[color_idx]
                dataset['borderColor'] =  colors_opaq[color_idx]
                dataset['lineTension'] = 0.4
                dataset['fill'] = 'origin'
                dataset['borderWidth'] = 1
                dataset['hidden'] = false
                values = []
                for point of data.task_result.result[ts][entry]
                    if !["min", "max", "avg"].includes(point)
                        labels.push point
                        values.push data.task_result.result[ts][entry][point]
                dataset['data'] = values
                datasets.push dataset
                color_idx += 1
            PRAUtils.build_graph("canvas_#{data['uuid']}_#{ts}", labels, datasets, 'line')

    @extract_words_results: (data)->
        colors = PRAUtils.generate_colors(3, "80")
        colors_opaq = PRAUtils.generate_colors(3, "FF")
        datasets = []
        labels = []
        dataset1 = {}
        dataset1['label'] = "Absolute Frequency"
        dataset1['backgroundColor'] =  colors[0]
        dataset1['borderColor'] =  colors_opaq[0]
        dataset1['lineTension'] = 0.4
        dataset1['fill'] = 'origin'
        dataset1['borderWidth'] = 1
        dataset1['hidden'] = true
        values1 = []

        dataset2 = {}
        dataset2['label'] = "Relative Frequency"
        dataset2['backgroundColor'] =  colors[1]
        dataset2['borderColor'] =  colors_opaq[1]
        dataset2['lineTension'] = 0.4
        dataset2['fill'] = 'origin'
        dataset2['borderWidth'] = 1
        dataset2['hidden'] = true
        values2 = []

        dataset3 = {}
        dataset3['label'] = "TF-IDF"
        dataset3['backgroundColor'] =  colors[2]
        dataset3['borderColor'] =  colors_opaq[2]
        dataset3['lineTension'] = 0.4
        dataset3['fill'] = 'origin'
        dataset3['borderWidth'] = 1
        dataset3['hidden'] = false
        values3 = []
        for entry of data.task_result.result['vocabulary']
            labels.push entry
            values1.push data.task_result.result['vocabulary'][entry][0]
            values2.push data.task_result.result['vocabulary'][entry][1]
            values3.push Math.exp(data.task_result.result['vocabulary'][entry][2])  # To modify when this is fixed !! negative tfidf values
        dataset1['data'] = values1
        dataset2['data'] = values2
        dataset3['data'] = values3
        datasets.push dataset1
        datasets.push dataset2
        datasets.push dataset3
        PRAUtils.build_graph("canvas_#{data['uuid']}", labels, datasets, 'bar', multiple_dataset_select=true)

    @extract_bigrams_results: (data)->
        colors = PRAUtils.generate_colors(3, "80")
        colors_opaq = PRAUtils.generate_colors(3, "FF")
        datasets = []
        labels = []
        dataset1 = {}
        dataset1['label'] = "Absolute Frequency"
        dataset1['backgroundColor'] =  colors[0]
        dataset1['borderColor'] =  colors_opaq[0]
        dataset1['lineTension'] = 0.4
        dataset1['fill'] = 'origin'
        dataset1['borderWidth'] = 1
        dataset1['hidden'] = true
        values1 = []

        dataset2 = {}
        dataset2['label'] = "Relative Frequency"
        dataset2['backgroundColor'] =  colors[1]
        dataset2['borderColor'] =  colors_opaq[1]
        dataset2['lineTension'] = 0.4
        dataset2['fill'] = 'origin'
        dataset2['borderWidth'] = 1
        dataset2['hidden'] = true
        values2 = []

        dataset3 = {}
        dataset3['label'] = "Dice Score"
        dataset3['backgroundColor'] =  colors[2]
        dataset3['borderColor'] =  colors_opaq[2]
        dataset3['lineTension'] = 0.4
        dataset3['fill'] = 'origin'
        dataset3['borderWidth'] = 1
        dataset3['hidden'] = false
        values3 = []

        for entry of data.task_result.result
            labels.push entry
            values1.push data.task_result.result[entry][0]
            values2.push data.task_result.result[entry][1]
            values3.push data.task_result.result[entry][2]
        dataset1['data'] = values1
        dataset2['data'] = values2
        dataset3['data'] = values3
        datasets.push dataset1
        datasets.push dataset2
        datasets.push dataset3
        PRAUtils.build_graph("canvas_#{data['uuid']}", labels, datasets, 'bar', multiple_dataset_select=true)

    @generate_colors: (number, alpha)->
        arr = ("##{c}#{alpha}" for c in palette('tol', number))
        return arr


    @build_graph: (canvas_id, labels, datasets, graph_type, multiple_dataset_select=false, multiple_axes=false)->
        ctx = $("##{canvas_id}")
        opts = {
            responsive: false,
            maintainAspectRatio: false,
            legend: {
                display: true
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
                        mode: 'xy'
                    },
                    zoom: {
                        enabled: true,
                        mode: 'x',
                    }
                }
            }
        }
        if multiple_axes
            opts['scales']['yAxes'] = [
                {
                    id: "saliency",
                    type: "linear",
                    position: "left",
                    fontColor: datasets[0]["backgroundColor"]
                },
                {
                    id: "stance",
                    type: "linear",
                    position: "right",
                    fontColor: datasets[1]["backgroundColor"],
                    ticks: {
                        min: -1,
                        max: 1,
                        stepSize: 0.5
                    }
                }
            ]
        if multiple_dataset_select
            opts['legend']['onClick'] = (e, legendItem)->
                index = legendItem.datasetIndex
                ci = this.chart
                ci.data.datasets.forEach (e, i)->
                    meta = ci.getDatasetMeta(i)
                    if i != index
                        meta.hidden = true
                    else
                        meta.hidden = false
                ci.update()
        console.log opts
        chart = new Chart(ctx, {
           type: graph_type,
           data: {
               labels: labels,
               datasets: datasets
           },
           options: opts
        })
        return chart