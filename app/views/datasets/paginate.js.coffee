pagenum = <%= @pagenum %>
nb_pages = <%= @nb_pages %>
$("#dataset_pagination").html("")
prev = $("<button class=\"btn btn-default\" data-action=\"prev\">&laquo;</button>")
prev.addClass("disabled") if pagenum == 1
$("#dataset_pagination").append prev
if nb_pages >= 10
    for i in [1..nb_pages]
        if i >= pagenum-2 && i <= pagenum+2
            button = $("<button class=\"btn btn-default\" data-action=\"page\">#{i}</button>")
            button.addClass "active" if pagenum == i
            $("#dataset_pagination").append button
        else if i <= 1
            button = $("<button class=\"btn btn-default\" data-action=\"page\">#{i}</button>")
            button.addClass "active" if pagenum == i
            $("#dataset_pagination").append button
        else if i >= nb_pages
            button = $("<button class=\"btn btn-default\" data-action=\"page\">#{i}</button>")
            button.addClass "active" if pagenum == i
            $("#dataset_pagination").append button
        if i == 2 && pagenum >= 5
            button = $("<button class=\"btn btn-default disabled\">...</button>")
            $("#dataset_pagination").append button
        if i == nb_pages-1 && pagenum <= nb_pages-4
            button = $("<button class=\"btn btn-default disabled\">...</button>")
            $("#dataset_pagination").append button


else
    for i in [1..nb_pages]
        button = $("<button class=\"btn btn-default\" data-action=\"page\">#{i}</button>")
        button.addClass "active" if pagenum == i
        $("#dataset_pagination").append button
next = $("<button class=\"btn btn-default\" data-action=\"next\">&raquo;</button>")
next.addClass "disabled" if pagenum == nb_pages
$("#dataset_pagination").append next

list = ""
<% @docs.each_with_index do |doc, doc_idx| %>
list += "<%= j(render partial: 'datasets/document', locals: {document: SolrDocument.new(doc), idx: @counter + doc_idx}) %>"
<% end %>
$("#dataset_documents_list").html(list)