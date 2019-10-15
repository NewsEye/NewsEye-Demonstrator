class @DatasetsEdit
    constructor: ->
        @setup_list_item_select()
        @setup_delete_form_submit()

    setup_list_item_select: ->
        for elt in $('ul.list-group li input')
            elt.checked = false
        $('ul.list-group li').click (e)->
            e.preventDefault()
            that = $(e.target)
            classlist = that.attr('class').split(/\s+/)
            if classlist.includes('active')
                that.find('input')[0].checked = false
                classlist.splice(classlist.indexOf('active'), 1)
            else
                that.find('input')[0].checked = true
                classlist.push('active')
            that.attr('class', classlist.join(' '))

    setup_delete_form_submit: ->
        $('#delete_form').submit ->
            searches = []
            for elt in $('ul#search_list li input:checked').toArray()
                searches.push(elt.parentNode.textContent)
            issues = []
            for elt in $('ul#issue_list li input:checked').toArray()
                issues.push(elt.parentNode.textContent)
            articles = []
            for elt in $('ul#article_list li input:checked').toArray()
                articles.push(elt.parentNode.textContent)
            $('input:hidden[name=\'searches[]\']').val(searches)
            $('input:hidden[name=\'issues[]\']').val(issues)
            $('input:hidden[name=\'articles[]\']').val(articles)
            return true