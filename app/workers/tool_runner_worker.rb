class ToolRunnerWorker
    include Sidekiq::Worker

    def perform(tool_id, user_id, tool_type, tool_parameters)
        tool = Tool.find(tool_id)
        tool.status = "running"
        tool.save!
        ActionCable.server.broadcast("notifications.#{user_id}", {
          type: "refresh_display",
          html: ApplicationController.render(partial: "experiment/tree", locals: {experiment: Experiment.find(tool.experiment.id)}),
          message: 'Starting job...' })
        case tool_type
        when "source_dataset"
            docs = fetch_docs_from_dataset(tool_parameters.select{|t| t['name'] == 'dataset'}[0]['value'])
            tool.results = {type:"documents", docs: docs}
            tool.status = "finished"
            tool.save!
            out = {
              type: "refresh_display",
              html: ApplicationController.render(partial: "experiment/tree", locals: {experiment: Experiment.find(tool.experiment.id)}),
              message: 'Done.'
            }
            ActionCable.server.broadcast("notifications.#{user_id}", out)
        when "ngrams"
            parent_output = Tool.find(tool.parent_id).results
            docs = parent_output["docs"].map{ |doc| doc['text'] }
            n = tool_parameters.select{|t| t['name'] == 'n'}[0]['value'].to_i
            min_freq = tool_parameters.select{|t| t['name'] == 'minimum_frequency'}[0]['value'].to_i
            ngrams = find_ngrams(docs, n, min_freq)
            tool.results = {type:"ngrams", ngrams: ngrams}
            tool.status = "finished"
            tool.save!
            out = {
              type: "refresh_display",
              html: ApplicationController.render(partial: "experiment/tree", locals: {experiment: Experiment.find(tool.experiment.id)}),
              message: 'Done.'
            }
            ActionCable.server.broadcast("notifications.#{user_id}", out)
        else

        end
    end

    def fetch_docs_from_dataset dataset_id
        d = Dataset.find(dataset_id)
        docs = d.fetch_paginated_documents(1, 99, "default", "asc", "all")
        docs[:docs].map do |doc|
            {
              id: doc['id'],
              newspaper: doc["member_of_collection_ids_ssim"][0],
              language: doc["language_ssi"],
              text: doc["all_text_tfr_siv"],
              date: doc["date_created_dtsi"]
            }
        end
    end

    def find_ngrams(documents, n, minimum_frequency)
        total = {}
        documents.each do |document|
            ngrams = document.split.each_cons(n).to_a
            ngrams.reject! { |w1, w2| w1 !~ /^\w+/ || w2 !~ /^\w+/ }
            ngrams.map!{ |ngram| ngram.join(' ') }
            total.merge!( ngrams.each_with_object(Hash.new(0)) do |word, obj|
                obj[word.downcase] += 1
            end)
        end
        total.sort_by { |k, v| -v }.reject { |k, v| v < minimum_frequency }
    end
end
