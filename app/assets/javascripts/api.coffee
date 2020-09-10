class @API
    @utilities: (callback)->
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/personal_research_assistant/utilities',
            method: 'GET',
            success: (data)->
                callback(data)
        }
    @topic_models: (callback)->
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/personal_research_assistant/topic_models',
            method: 'GET',
            success: (data)->
                callback(data)
        }
    @user_tasks: (utilities, callback)->
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/personal_research_assistant/user_tasks',
            method: 'POST',
            data: {utilities: utilities},
            success: (data)->
                callback(data)
        }
    @render_utility: (utility, topic_models, user_tasks, callback)->
        # hack to pass the array even if it is empty
        if user_tasks.size == 0
            user_tasks = [""]
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/personal_research_assistant/render_utility',
            method: 'POST',
            data:{utility: utility, topic_models: topic_models, user_tasks: user_tasks},
            success: (data)->
                callback(data)
        }
    @np_stats: (callback)->
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/get_stats',
            method: 'GET',
            success: (data)->
                callback(data)
        }
    @task_results: (parent_task_uuid, task_uuid, callback)->
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/personal_workspace/get_task_results',
            method: 'POST',
            data:{parent_task_uuid: parent_task_uuid, task_uuid: task_uuid},
            success: (data)->
                callback(data)
        }
    @query_task_results: (task_uuid, callback)->
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/personal_workspace/query_task_results',
            method: 'POST',
            data:{task_uuid: task_uuid},
            success: (data)->
                callback(data)
        }
    @topic_query_results: (task_uuid, callback)->
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/topic_models/query_results',
            method: 'POST',
            data:{task_uuid: task_uuid},
            success: (data)->
                callback(data)
        }
    @run_report: (run_uuid, callback)->
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/personal_workspace/get_run_report',
            method: 'POST',
            data:{run_uuid: run_uuid},
            success: (data)->
                callback(data)
        }
    @task_report: (task_uuid, callback)->
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/personal_workspace/get_task_report',
            method: 'POST',
            data:{task_uuid: task_uuid},
            success: (data)->
                callback(data)
        }
    @get_run_id_from_experiment_id: (experiment_id, callback)->
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/experiment/get_run_id',
            method: 'POST',
            data:{experiment_id: experiment_id},
            success: (data)->
                callback(data)
        }
    @working_dataset: (callback)->
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/catalog/set_working_dataset',
            method: 'GET',
            success: (data)->
                callback(data)
        }
    @get_article_images: (article_id, callback)->
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/catalog/article_parts',
            method: 'POST',
            data:{article_id: article_id},
            success: (data)->
                callback(data)
        }
    @get_topic_description: (model_type, model_name, topic_number, year, callback)->
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/topic_models/describe',
            method: 'POST',
            data:{model_type: model_type, model_name: model_name, topic_number: topic_number, year: year},
            success: (data)->
                callback(data)
        }
    @get_mirador_config: (doc_id, callback)->
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/catalog/get_mirador_config',
            method: 'POST',
            data:{id: doc_id},
            success: (data)->
                callback(data)
        }
    @get_min_max_dates: (callback)->
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/get_min_max_dates',
            method: 'GET',
            success: (data)->
                callback(data)
        }
    @get_datasets_with_doc: (doc_id, callback)->
        $.ajax {
                    url:  window.location.protocol+"//"+window.location.host+'/datasets/get_datasets_with_doc',
                    method: 'POST',
                    data:{id: doc_id},
                    success: (data)->
                        callback(data)
                }
    @load_graph: (experiment_id, callback)->
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/experiment/load',
            method: 'POST',
            data:{experiment_id: experiment_id},
            success: (data)->
                callback(data)
        }
    @save_graph: (elements, experiment_id, callback)->
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/experiment/save',
            method: 'POST',
            data:{experiment_id: experiment_id, elements: elements},
            success: (data)->
                callback(data)
        }
    @add_query_to_dataset: (params, dataset_id, relevancy, callback)->
        $.ajax {
            url:  window.location.protocol+"//"+window.location.host+'/add_query_to_dataset',
            method: 'POST',
            data:{params: params, dataset_id: dataset_id, relevancy: relevancy},
            success: (data)->
                callback(data)
        }