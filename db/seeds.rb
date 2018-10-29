puts "seeding..."

json_data = JSON.parse(File.read(File.join(File.dirname(__FILE__), './seeds_data/data.json')))

json_data.each do |newspaper|
  newspaper = newspaper.with_indifferent_access
  puts "adding newspaper %s" % newspaper[:title]
  np = Newspaper.new
  np.id = newspaper[:title].to_ascii.sub(' ', '_')
  np.title = newspaper[:title]
  np.publisher = newspaper[:publisher]
  np.language = newspaper[:language]
  np.datefrom = newspaper[:datefrom]
  np.dateto = newspaper[:dateto]
  np.location = newspaper[:location]
  np.save
  newspaper[:issues].each do |np_issue|
    puts "adding issue %s" % np_issue[:id]
    issue = Issue.new
    issue.original_uri = np_issue[:original_uri]
    issue.id = np.id + '_' + np_issue[:id]
    issue.publisher = np_issue[:publisher]
    issue.title = np_issue[:title]
    issue.date_created = np_issue[:date_created]
    issue.language = np_issue[:language]
    issue.nb_pages = np_issue[:nb_pages]
    issue.thumbnail_url = np_issue[:thumbnail_url]
    issue.save
    issue_ocr_text = ''
    np_issue[:pages].each do |issue_page|
      puts "adding page %i out of %i" % [issue_page[:page_number], np_issue[:pages].length]

      pfs = PageFileSet.new
      pfs.id = issue.id + '_' + issue_page[:id].split('_')[1..-1].join('_')
      pfs.page_number = issue_page[:page_number]

      image_full = open(Rails.root.to_s + issue_page[:image_path], 'r')
      Hydra::Works::AddFileToFileSet.call(pfs, image_full, :original_file)
      Hydra::Works::CharacterizationService.run pfs.original_file
      pfs.height = pfs.original_file.height.first
      pfs.width = pfs.original_file.width.first
      pfs.mime_type = pfs.original_file.mime_type

      ocr_file = open(Rails.root.to_s + issue_page[:ocr_path], 'r')
      Hydra::Works::AddFileToFileSet.call(pfs, ocr_file, :alto_xml)
      ocr = Nokogiri::XML(open(ocr_file).read, 'UTF-8')
      ocr.remove_namespaces!
      page_ocr_text = ''
      ocr.xpath('//TextLine').each do |line|
        line.xpath('./String').each do |word|
          page_ocr_text += word['CONTENT'] + ' '
        end
        page_ocr_text.strip!
        page_ocr_text += "\n"
      end
      page_ocr_text.strip!

      pfs.save
      issue.ordered_members << pfs
      pfs.save
      issue.save
      issue_ocr_text += page_ocr_text
    end
    issue.all_text = issue_ocr_text
    np.members << issue
    issue.member_of_collections << np
    issue.save
    np.save
  end
end