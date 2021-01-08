# -*- encoding : utf-8 -*-

class ExportController < ApplicationController

    def csv_export
        dataset = Dataset.find(params[:id])
        filename = "/tmp/export_#{dataset.title.parameterize(separator: '_')}_#{Time.now.strftime("%d_%m_%Y_%H_%M")}.csv"
        to_write = []
        dataset.fetch_documents.map do |solr_doc|
            lang = solr_doc['language_ssi']
            text_entry = solr_doc["all_text_t#{lang}_siv"].gsub("\"", "\"\"")
            text_entry = "\"#{text_entry}\""
            thumb = solr_doc['thumbnail_url_ss_list'].nil? ? solr_doc['thumbnail_url_ss'] : solr_doc['thumbnail_url_ss_list']
            to_write << ["\"#{solr_doc['id']}\"",
                         "\"#{lang}\"",
                         "\"#{solr_doc['date_created_dtsi']}\"",
                         "\"#{solr_doc['member_of_collection_ids_ssim'][0]}\"",
                         "\"#{thumb}\"",
                         "\"#{solr_doc['relevancy']}\"",
                         text_entry].join(',')
        end
        File.open(filename, 'w') do |f|
            f.write "id,language,date,newspaper_id,iiif_url,relevancy,text\n"
            f.write to_write.join("\n")
        end
        File.open(filename, 'r') do |f|
            send_data f.read, type: "text/csv", filename: filename.split('/')[-1]
        end
        File.delete(filename)
    end

    def excel_export
        dataset = Dataset.find(params[:id])
        filename = "/tmp/export_#{dataset.title.parameterize(separator: '_')}_#{Time.now.strftime("%d_%m_%Y_%H_%M")}.ods"
        ods = RODF::Spreadsheet.new
        p = Proc.new { |doc|
            doc.style "headings", family: :cell do
                property :text, 'font-weight': "bold"
            end
            doc.table dataset.title do
                row do
                    cell 'ID', type: :string, style: "headings"
                    cell 'Language', type: :string, style: "headings"
                    cell 'Date', type: :string, style: "headings"
                    cell 'NewspaperID', type: :string, style: "headings"
                    cell 'IIIF URL', type: :string, style: "headings"
                    cell 'Relevancy', type: :string, style: "headings"
                    cell 'Text', type: :string, style: "headings"
                end
                dataset.fetch_documents.map do |solr_doc|
                    thumb = solr_doc['thumbnail_url_ss_list'].nil? ? solr_doc['thumbnail_url_ss'] : solr_doc['thumbnail_url_ss_list']
                    row do
                        cell solr_doc['id']
                        cell solr_doc['language_ssi']
                        cell solr_doc['date_created_dtsi']
                        cell solr_doc['member_of_collection_ids_ssim'][0]
                        cell thumb
                        cell solr_doc['relevancy']
                        cell solr_doc["all_text_t#{solr_doc['language_ssi']}_siv"].gsub("\"", "\"\"")
                    end
                end
            end
        }
        p.call ods
        send_data ods.bytes, type: "application/vnd.oasis.opendocument.spreadsheet", filename: filename.split('/')[-1]
    end

    def json_export
        dataset = Dataset.find(params[:id])
        filename = "/tmp/export_#{dataset.title.parameterize(separator: '_')}_#{Time.now.strftime("%d_%m_%Y_%H_%M")}.json"
        to_write = []
        named_entities = dataset.get_entities
        named_entities = named_entities.values.map{|h| h.values }.flatten
        puts named_entities
        dataset.fetch_documents.map do |solr_doc|
            puts solr_doc
            lang = solr_doc['language_ssi']
            thumb = solr_doc['thumbnail_url_ss_list'].nil? ? solr_doc['thumbnail_url_ss'] : solr_doc['thumbnail_url_ss_list'].split("\n")
            if solr_doc["article_parts_ssim"]  # solr_doc type : compound
                doc_type = "compound"
                entities = named_entities.select{ |ne| solr_doc['article_parts_ssim'].include? ne['article_id_ssi'] }
            elsif solr_doc["has_model_ssim"].include? "Article" # solr_doc type : article
                doc_type = "article"
                entities = named_entities.select{ |ne| solr_doc['id'] == ne['article_id_ssi'] }
            elsif solr_doc["has_model_ssim"].include? "Issue" # solr_doc type : issue
                doc_type = "issue"
                entities = named_entities.select{ |ne| solr_doc['id'] == ne['issue_id_ssi'] }
            end
            entities = entities.map do |ne|
                {
                  mention: ne['mention_ssi'],
                  indexStart: ne['article_index_start_isi'],
                  indexEnd: ne['article_index_end_isi'],
                  stance: if ne['stance_fsi'] == 0
                              "neutral"
                          else
                              ne['stance_fsi'] > 0 ? "positive" : "negative"
                          end,
                  linked_entity_url: ne['linked_entity_ssi'] == "" ? nil : "https://www.wikidata.org/wiki/#{ne['linked_entity_ssi'].split('_')[-1]}"
                }
            end
            to_write << { id: solr_doc['id'],
                          type: doc_type,
                          language: lang,
                          date: solr_doc['date_created_dtsi'],
                          newspaper_id: solr_doc['member_of_collection_ids_ssim'][0],
                          iiif_url: thumb,
                          relevancy: solr_doc['relevancy'],
                          text: solr_doc["all_text_t#{lang}_siv"],
                          named_entities: entities }
        end
        File.open(filename, 'w') do |f|
            f.write to_write.to_json
        end
        File.open(filename, 'r') do |f|
            send_data f.read, type: "text/json", filename: filename.split('/')[-1]
        end
        File.delete(filename)
    end

    def zipped_export
        dataset = Dataset.find(params[:id])
        zip_name = "/tmp/export_#{dataset.title.parameterize(separator: '_')}_#{Time.now.strftime("%d_%m_%Y_%H_%M")}.zip"
        files_to_send = dataset.fetch_documents.map do |solr_doc|
            filename = "#{solr_doc['relevancy']}_#{solr_doc['date_created_dtsi'][0...solr_doc['date_created_dtsi'].index('T')]}_#{solr_doc['id']}.txt"
            file_content = solr_doc["all_text_t#{solr_doc['language_ssi']}_siv"]
            File.open("/tmp/#{filename}", 'w') do |f|
                f.write file_content
            end
            filename
        end
        Zip::File.open(zip_name, Zip::File::CREATE) do |zipfile|
            files_to_send.each do |filename|
                zipfile.add filename,  "/tmp/#{filename}"
            end
        end
        File.open(zip_name, 'r') do |f|
            send_data f.read, type: "application/zip", filename: zip_name.split('/')[-1]
        end
        files_to_send.each do |filename|
            File.delete("/tmp/#{filename}")
        end
        File.delete(zip_name)
    end
end