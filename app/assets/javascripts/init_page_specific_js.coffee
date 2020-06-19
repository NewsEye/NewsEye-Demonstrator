class Init
    constructor: ->
        page = $('body').attr('class').split(' ')[1]
        console.log "init page specific for #{page}"
        page = ((part[0].toUpperCase() + part.slice(1) for part in p.split('_')).join('') for p in page.split('-').splice(1, 2)).join('')
        @current_page_class =  @execute_page_js(page)
        @setup_cursors_wait()
        @setup_help_modal()
        @setup_video_modal()
        @setup_kw_suggest_modal()
        @set_search_default()

    execute_page_js: (page)->
        if 'function' is typeof window[page]
            klass = window[page]
            return new klass()

    setup_cursors_wait: ->
        $(document).on 'turbolinks:click', ->
            $('body').css( 'cursor', 'progress' )
        $(document).on 'turbolinks:load', ->
            $('body').css( 'cursor', 'default' )

    setup_help_modal: ->
        $('button#help_modal').click (e)->
            $.ajax {
                url:  window.location.protocol+"//"+window.location.host+'/search_help',
                method: 'GET'
            }

    setup_video_modal: ->
        $('li#video_modal').click (e)->
            $.ajax {
                url:  window.location.protocol+"//"+window.location.host+'/platform_help',
                method: 'GET'
            }

    setup_kw_suggest_modal: ->
        $('#kw_suggest_modal').click (e)->
            $.ajax {
                url:  window.location.protocol+"//"+window.location.host+'/kw_suggest',
                method: 'GET'
            }

    set_search_default: ->
        if $("#search_field").length > 0
            $("#search_field").html($("#search_field option").sort (a,b)->
                return a.text == b.text ? 0 : a.value == "all_fields" ? 1 : -1
            )

global = @
$(document).on 'turbolinks:load', ->
    init = new Init()
    global.current_page_class = init.current_page_class