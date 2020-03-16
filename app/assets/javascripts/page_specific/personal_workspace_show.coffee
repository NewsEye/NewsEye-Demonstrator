class @PersonalWorkspaceShow
    constructor: ->
        self = @
        console.log 'show'
        main_classes = $("div.main_task").attr("class").split(' ')
        main_classes.splice(main_classes.indexOf("main_task"),1)
        task_type = main_classes[0]
        console.log task_type
        if task_type == "describe_search" or task_type == "describe_dataset"
            @process_results()
            @load_reports()
        if task_type == "tm_query"
            @topics()

    topics: ()->
        console.log "load topics"
        self = @
        task_uuid = $($("div.main_task")[0]).attr('id')
        API.topic_query_results task_uuid, (data)->
            console.log data
            datasets = []
            labels = []
            dataset = {}
            dataset['label'] = "Topics distribution"
            dataset['backgroundColor'] =  'rgba(200, 200, 200, 0.5)'
            dataset['borderColor'] =  'rgba(50, 50, 50, 1)'
            dataset['lineTension'] = 0.4
            dataset['fill'] = 'origin'
            dataset['borderWidth'] = 1
            dataset['hidden'] = false
            values = []
            for value, index in data['topic_weights']
                labels.push index+1
                values.push value
            dataset['data'] = values
            datasets.push dataset
            self.build_graph("canvas_#{data['uuid']}", labels, datasets)


    load_reports: ->
        console.log "load reports"
        self = @
        parent_uuid = $($("div.main_task")[0]).attr('id')
        API.run_report parent_uuid, (data)->
            $("#run_report").html data['body']
        for subtask in $("div.subtask")
            uuid = $(subtask).attr('id')
            API.task_report uuid, (data)->
                $("##{data['task_uuid']}_report").html data['body']

    process_results: ->
        console.log "process results"
        self = @
        parent_uuid = $($("div.main_task")[0]).attr('id')
        for subtask in $("div.subtask")
            uuid = $(subtask).attr('id')
            subtask_name = $("##{uuid} .subtask_name")[0].textContent

            if subtask_name == "ExtractFacets"
                self.build_extract_facets(parent_uuid, uuid)

            if subtask_name == "ExtractWords"
                self.build_extract_words(parent_uuid, uuid)

            if subtask_name == "ExtractBigrams"
                self.build_extract_bigrams(parent_uuid, uuid)

            if subtask_name == "GenerateTimeSeries"
                self.build_generate_time_series(parent_uuid, uuid)


    build_extract_facets: (parent_uuid, uuid)->
        self = @
        API.task_results parent_uuid, uuid, (data)->
            for facet of data['result']
                datasets = []
                labels = []
                dataset = {}
                dataset['label'] = facet
                dataset['backgroundColor'] =  'rgba(200, 200, 200, 0.5)'
                dataset['borderColor'] =  'rgba(50, 50, 50, 1)'
                dataset['lineTension'] = 0.4
                dataset['fill'] = 'origin'
                dataset['borderWidth'] = 1
                dataset['hidden'] = false
                values = []
                for point of data['result'][facet]
                    labels.push point
                    values.push data['result'][facet][point]
                dataset['data'] = values
                datasets.push dataset
                self.build_graph("canvas_#{data['uuid']}_#{facet}", labels, datasets)

    build_extract_words: (parent_uuid, uuid)->
        self = @
        API.task_results parent_uuid, uuid, (data)->
            datasets = []
            labels = []
            dataset1 = {}
            dataset1['label'] = "Absolute Frequency"
            dataset1['backgroundColor'] =  'rgba(200, 200, 200, 0.5)'
            dataset1['borderColor'] =  'rgba(50, 50, 50, 1)'
            dataset1['lineTension'] = 0.4
            dataset1['fill'] = 'origin'
            dataset1['borderWidth'] = 1
            dataset1['hidden'] = true
            values1 = []

            dataset2 = {}
            dataset2['label'] = "Relative Frequency"
            dataset2['backgroundColor'] =  'rgba(200, 200, 200, 0.5)'
            dataset2['borderColor'] =  'rgba(50, 50, 50, 1)'
            dataset2['lineTension'] = 0.4
            dataset2['fill'] = 'origin'
            dataset2['borderWidth'] = 1
            dataset2['hidden'] = true
            values2 = []

            dataset3 = {}
            dataset3['label'] = "TF-IDF"
            dataset3['backgroundColor'] =  'rgba(200, 200, 200, 0.5)'
            dataset3['borderColor'] =  'rgba(50, 50, 50, 1)'
            dataset3['lineTension'] = 0.4
            dataset3['fill'] = 'origin'
            dataset3['borderWidth'] = 1
            dataset3['hidden'] = false
            values3 = []

            for entry of data['result']['vocabulary']
                labels.push entry
                values1.push data['result']['vocabulary'][entry][0]
                values2.push data['result']['vocabulary'][entry][1]
                values3.push Math.exp(data['result']['vocabulary'][entry][2])  # To modify when this is fixed !! negative tfidf values
            dataset1['data'] = values1
            dataset2['data'] = values2
            dataset3['data'] = values3
            datasets.push dataset1
            datasets.push dataset2
            datasets.push dataset3
            self.build_graph("canvas_#{data['uuid']}", labels, datasets)

    build_extract_bigrams: (parent_uuid, uuid)->
        self = @
        API.task_results parent_uuid, uuid, (data)->
            datasets = []
            labels = []
            dataset1 = {}
            dataset1['label'] = "Absolute Frequency"
            dataset1['backgroundColor'] =  'rgba(200, 200, 200, 0.5)'
            dataset1['borderColor'] =  'rgba(50, 50, 50, 1)'
            dataset1['lineTension'] = 0.4
            dataset1['fill'] = 'origin'
            dataset1['borderWidth'] = 1
            dataset1['hidden'] = true
            values1 = []

            dataset2 = {}
            dataset2['label'] = "Relative Frequency"
            dataset2['backgroundColor'] =  'rgba(200, 200, 200, 0.5)'
            dataset2['borderColor'] =  'rgba(50, 50, 50, 1)'
            dataset2['lineTension'] = 0.4
            dataset2['fill'] = 'origin'
            dataset2['borderWidth'] = 1
            dataset2['hidden'] = true
            values2 = []

            dataset3 = {}
            dataset3['label'] = "Dice Score"
            dataset3['backgroundColor'] =  'rgba(200, 200, 200, 0.5)'
            dataset3['borderColor'] =  'rgba(50, 50, 50, 1)'
            dataset3['lineTension'] = 0.4
            dataset3['fill'] = 'origin'
            dataset3['borderWidth'] = 1
            dataset3['hidden'] = false
            values3 = []

            for entry of data['result']
                labels.push entry
                values1.push data['result'][entry][0]
                values2.push data['result'][entry][1]
                values3.push data['result'][entry][2]
            dataset1['data'] = values1
            dataset2['data'] = values2
            dataset3['data'] = values3
            datasets.push dataset1
            datasets.push dataset2
            datasets.push dataset3
            self.build_graph("canvas_#{data['uuid']}", labels, datasets)

    build_generate_time_series: (parent_uuid, uuid)->
        self = @
        API.task_results parent_uuid, uuid, (data)->
            for ts of data['result']
                datasets = []
                for entry of data['result'][ts]
                    labels = []
                    dataset = {}
                    dataset['label'] = entry
                    dataset['backgroundColor'] =  'rgba(200, 200, 200, 0.5)'
                    dataset['borderColor'] =  'rgba(50, 50, 50, 1)'
                    dataset['lineTension'] = 0.4
                    dataset['fill'] = 'origin'
                    dataset['borderWidth'] = 1
                    dataset['hidden'] = false
                    values = []
                    for point of data['result'][ts][entry]
                        if !["min", "max", "avg"].includes(point)
                            labels.push point
                            values.push data['result'][ts][entry][point]
                    dataset['data'] = values
                    datasets.push dataset
                self.build_graph("canvas_#{data['uuid']}_#{ts}", labels, datasets)

    build_graph: (canvas_id, labels, datasets)->
        ctx = $("##{canvas_id}")
        new Chart(ctx, {
           type: 'line',
           data: {
               labels: labels,
               datasets: datasets
           },
           options: {
               responsive: true,
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
               }
           }
        })
