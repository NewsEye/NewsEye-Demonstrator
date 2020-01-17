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