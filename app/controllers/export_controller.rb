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
      to_write << ["\"#{solr_doc['id']}\"",
                   "\"#{lang}\"",
                   "\"#{solr_doc['date_created_dtsi']}\"",
                   "\"#{solr_doc['member_of_collection_ids_ssim'][0]}\"",
                   "\"#{solr_doc['thumbnail_url_ss']}\"",
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

  def json_export
    dataset = Dataset.find(params[:id])
    filename = "/tmp/export_#{dataset.title.parameterize(separator: '_')}_#{Time.now.strftime("%d_%m_%Y_%H_%M")}.json"
    to_write = []
    dataset.fetch_documents.map do |solr_doc|
      lang = solr_doc['language_ssi']
      to_write << { id: solr_doc['id'],
                    language: lang,
                    date: solr_doc['date_created_dtsi'],
                    newspaper_id: solr_doc['member_of_collection_ids_ssim'][0],
                    iiif_url: solr_doc['thumbnail_url_ss'],
                    relevancy: solr_doc['relevancy'],
                    text: solr_doc["all_text_t#{lang}_siv"] }
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
      filename = "#{solr_doc['relevancy']}_#{solr_doc['date_created_ssi']}_#{solr_doc['id']}.txt"
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