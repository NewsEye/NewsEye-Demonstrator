puts "seeding..."

json_data = JSON.parse(File.read('/home/axel/Nextcloud/NewsEye/newseye_samvera/test_data/data.json'))

json_data.each do |newspaper|
  newspaper = newspaper.with_indifferent_access
  puts "adding newspaper %s" % newspaper[:title]
  np = Newspaper.new
  np.id = newspaper[:title].to_ascii
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
      pfs.id = issue.id + '_' + issue_page[:id]
      pfs.page_number = issue_page[:page_number]
      ocr_file = open(issue_page[:ocr_path], 'r')
      image_full = open(issue_page[:image_path], 'r')
      Hydra::Works::UploadFileToFileSet.call(pfs, image_full)
      Hydra::Works::AddFileToFileSet.call(pfs, ocr_file, :extracted_text)
      ocr = Nokogiri::XML(open(ocr_file).read, 'UTF-8')
      page_ocr_text = ''
      ocr.xpath('//TextLine').each do |line|
        line.xpath('./String').each do |word|
          page_ocr_text += word['CONTENT'] + ' '
        end
        page_ocr_text.strip!
        page_ocr_text += "\n"
      end
      page_ocr_text.strip!
      pfs.build_extracted_text
      pfs.extracted_text.content = page_ocr_text
      pfs.save
      issue.members << pfs
      issue_ocr_text += page_ocr_text
    end
    issue.all_text = issue_ocr_text
    np.members << issue
  end
end