class Init
    constructor: ->
        page = $('body').attr('class').split(' ')[1]
        console.log "init page specific for #{page}"
        page = ((part[0].toUpperCase() + part.slice(1) for part in p.split('_')).join('') for p in page.split('-').splice(1, 2)).join('')
        @execute_page_js(page)

    execute_page_js: (page)->
        if 'function' is typeof window[page]
            klass = window[page]
            new klass()
$(document).on 'turbolinks:load', ->
    new Init()