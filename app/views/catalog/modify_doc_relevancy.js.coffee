$("#main-flashes").html '<%= j render partial: "/flash_msg" %>'
API.get_datasets_with_doc "<%= @doc_id %>", (data)->
    console.log data
    if(data.length > 0)
        datasets = $("<p style=\"font-style: italic;\">Currently belongs to: </p>")
        for obj in data
            relevancy_mapping = {
                0: ['dark', 'Not relevant'],
                1: ['light', 'Somewhat relevant'],
                2: ['info', 'Relevant'],
                3: ['primary', 'Very relevant']
            }
        badge_type = relevancy_mapping[obj[2]][0]
        tooltip = relevancy_mapping[obj[2]][1]
        a = $("<a href=\"/datasets/#{obj[0]}\"></a>")
        span = $("<span class=\"dataset-#{obj[0]} badge badge-#{badge_type}\" title=\"#{tooltip}\" data-relevancy=\"#{obj[2]}\">#{obj[1]}</span>")
        a.append span
        datasets.append a
        <% if @compound %>
        $("#compound_article_in_datasets_list").html datasets[0].outerHTML
        <% elsif @doc_id.include?("_article_")%>
        $("#article_in_datasets_list").html datasets[0].outerHTML
        <% else %>
        $("#issue_in_datasets_list").html datasets[0].outerHTML
        <% end %>
    else
        <% if @compound %>
        $("#compound_article_in_datasets_list").html ""
        <% elsif @doc_id.include?("_article_")%>
        $("#article_in_datasets_list").html ""
        <% else %>
        $("#issue_in_datasets_list").html ""
        <% end %>
<% d = Dataset.find session[:working_dataset] %>
<% working_dataset_title = "#{d.title} (#{d.documents.size} docs)" %>
$("#working_dataset_select").children("option:selected").text("<%= working_dataset_title %>")