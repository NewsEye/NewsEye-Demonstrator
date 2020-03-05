class @CatalogExplore
    constructor: ->
        self = @
        console.log 'explorer'
        @build_chart()
        @setup_select()

    setup_select: ->
        self = @
        $('#select_np li').click (e)->
            chart = Chart.instances[0]
            e.preventDefault()
            that = $(e.target)
            classlist = that.attr('class').split(/\s+/)
            new_state = true
            if classlist.includes('np_selected')
                new_state = false
                classlist.splice(classlist.indexOf('np_selected'), 1)
                that.find("span").css('visibility', 'hidden' )
            else
                new_state = true
                classlist.push('np_selected')
                that.find("span").css('visibility', 'visible' )
            that.attr('class', classlist.join(' '))

            if that.attr('id') != "select_all_datasets"
                for index in [0...chart.data.datasets.length]
                    dataset = chart.data.datasets[index]
                    if dataset.label == that.text()
                        meta = chart.getDatasetMeta(index)
                        meta.hidden = if meta.hidden == null then !chart.data.datasets[index].hidden else !meta.hidden
            else
                that.text("Unselect all") if new_state
                that.text("Select all") if !new_state
                for index in [0...chart.data.datasets.length]
                    meta = chart.getDatasetMeta(index)
                    meta.hidden = !new_state
                for li in $('li.npids')
                    classlist = $(li).attr('class').split(/\s+/)
                    if new_state
                        classlist.push('np_selected') if !classlist.includes('np_selected')
                        $(li).find("span").css('visibility', 'visible' )
                    else
                        classlist.splice(classlist.indexOf('np_selected'), 1) if classlist.includes('np_selected')
                        $(li).find("span").css('visibility', 'hidden' )
                    $(li).attr('class', classlist.join(' '))
            chart.update()

    build_chart: ->
        self = @
        API.np_stats (data)->
            datasets = []
            labels = []
            for npid of data
                labels = []
                dataset = {}
                dataset['label'] = npid
                dataset['backgroundColor'] =  'rgba(200, 200, 200, 0.5)'
                dataset['borderColor'] =  'rgba(50, 50, 50, 1)'
                dataset['lineTension'] = 0.4
                dataset['fill'] = 'origin'
                dataset['borderWidth'] = 1
                dataset['hidden'] = true
                values = []
                for point in data[npid]
                    labels.push (new Date(point[0])).getFullYear()
                    values.push point[1]
                dataset['data'] = values
                datasets.push dataset
            ctx = $('#myChart')
            new Chart(ctx, {
               type: 'line',
               data: {
                   labels: labels.map(String),
                   datasets: datasets
               },
               options: {
                   responsive: true,
                   maintainAspectRatio: false,
                   legend: {
                       display: false
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
