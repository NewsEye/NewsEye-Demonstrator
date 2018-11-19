
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
    issue.save
    issue_ocr_text = ''
    np_issue[:pages].each do |issue_page|
      puts "adding page %i out of %i" % [issue_page[:page_number], np_issue[:pages].length]

      pfs = PageFileSet.new
      pfs.id = issue.id + '_' + issue_page[:id].split('_')[1..-1].join('_')
      pfs.page_number = issue_page[:page_number]

      if issue.original_uri.include? 'ark:/' # If there exists an iiif image service
        pfs.iiif_url = (issue.original_uri + "/f#{pfs.page_number}").insert(issue.original_uri.index('ark:/'), 'iiif/')
        info_json = JSON.load(open(pfs.iiif_url+'/info.json'))
        pfs.height = info_json['height'].to_i
        pfs.width = info_json['width'].to_i
        pfs.mime_type = 'image/jpeg'
        if issue_page[:page_number] == 1
          issue.thumbnail_url = "#{pfs.iiif_url}/full/,200/0/default.jpg"
        end
      else # Else import image
        open(Rails.root.to_s + issue_page[:image_path], 'r') do |image_full|
          Hydra::Works::AddFileToFileSet.call(pfs, image_full, :original_file)
        end
        Hydra::Works::CharacterizationService.run pfs.original_file
        pfs.height = pfs.original_file.height.first
        pfs.width = pfs.original_file.width.first
        pfs.mime_type = pfs.original_file.mime_type
        if issue_page[:page_number] == 1
          issue.thumbnail_url = "http://localhost:3000/iiif/#{issue.id}_page_1/full/,200/0/default.jpg"
        end
      end

      ###### Parse OCR and add full text property ######

      encoding = CharlockHolmes::EncodingDetector.detect(File.read(Rails.root.to_s + issue_page[:ocr_path]))[:ruby_encoding]
      ocr_file = open(Rails.root.to_s + issue_page[:ocr_path], 'r')
      Hydra::Works::AddFileToFileSet.call(pfs, ocr_file, :alto_xml)
      ocr = File.open(Rails.root.to_s + issue_page[:ocr_path]) do |f|
        Nokogiri::XML(f, nil, encoding)
      end
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

      ###### IIIF Annotation generation ######

      annotation_file = Tempfile.new(%w(annotation_list_word_level .json), Rails.root.to_s + '/tmp', encoding: 'UTF-8')
      annotation_file.write(parse_alto_word(ocr, issue.id, pfs.page_number, encoding))
      annotation_file.close
      annotation_file = open(annotation_file.path, 'r')
      Hydra::Works::AddFileToFileSet.call(pfs, annotation_file, :ocr_word_level_annotation_list)

      annotation_file = Tempfile.new(%w(annotation_list_line_level .json), Rails.root.to_s + '/tmp', encoding: 'UTF-8')
      annotation_file.write(parse_alto_line(ocr, issue.id, pfs.page_number, encoding))
      annotation_file.close
      annotation_file = open(annotation_file.path, 'r')
      Hydra::Works::AddFileToFileSet.call(pfs, annotation_file, :ocr_line_level_annotation_list)

      annotation_file = Tempfile.new(%w(annotation_list_block_level .json), Rails.root.to_s + '/tmp', encoding: 'UTF-8')
      annotation_file.write(parse_alto_block(ocr, issue.id, pfs.page_number, encoding))
      annotation_file.close
      annotation_file = open(annotation_file.path, 'r')
      Hydra::Works::AddFileToFileSet.call(pfs, annotation_file, :ocr_block_level_annotation_list)

      ###### Finalize ######

      pfs.save
      issue.ordered_members << pfs
      pfs.save
      issue.save
      issue_ocr_text += page_ocr_text
    end
    puts "Sending annotations to server..."
    issue.ordered_members.to_a.select(&:file_set?).each do |pfs|
      ['block'].each do |layer|
        HTTParty.post('http://localhost:8888/annotation/populate',
                      body: {
                          uri: "http://localhost:3000/iiif/#{issue.id}/list/page_#{pfs.page_number}_ocr_#{layer}_level"
                      })
      end
    end
    issue.all_text = issue_ocr_text
    np.members << issue
    issue.member_of_collections << np
    issue.save
    np.save
  end
end

BEGIN {
  def parse_alto_word(doc, doc_id, page_num, encoding)
    annotation_list = {}
    annotation_list['@context'] = 'http://iiif.io/api/presentation/2/context.json'
    annotation_list['@id'] = "<host>/iiif/#{doc_id}/list/page_#{page_num}_ocr_word_level"
    annotation_list['@type'] = 'sc:AnnotationList'
    annotation_list['resources'] = []

    doc.xpath('//String').each do |str|
      annot = {}
      annot['@type'] = 'oa:Annotation'
      annot['motivation'] = 'sc:painting'
      annot['resource'] = {}
      annot['resource']['@type'] = 'cnt:ContentAsText'
      annot['resource']['format'] = 'text/plain'
      annot['resource']['chars'] = str['CONTENT'].force_encoding(encoding).encode('UTF-8')
      annot['metadata'] = {}
      annot['metadata']['word_confidence'] = str['WC'].to_f
      annot['on'] = "<host>/iiif/#{doc_id}/canvas/page_#{page_num}#xywh=#{str['HPOS']},#{str['VPOS']},#{str['WIDTH']},#{str['HEIGHT']}"
      annotation_list['resources'] << annot
    end

    annotation_list['within'] = {}
    annotation_list['within']['@id'] = "<host>/iiif/#{doc_id}/layer/ocr_word_level"
    annotation_list['within']['@type'] = 'sc:Layer'
    annotation_list['within']['label'] = 'OCR Layer'
    annotation_list.to_json
  end

  def parse_alto_line(doc, doc_id, page_num, encoding)
    annotation_list = {}
    annotation_list['@context'] = 'http://iiif.io/api/presentation/2/context.json'
    annotation_list['@id'] = "<host>/iiif/#{doc_id}/list/page_#{page_num}_ocr_line_level"
    annotation_list['@type'] = 'sc:AnnotationList'
    annotation_list['resources'] = []

    doc.xpath('//TextLine').each do |line|
      annot = {}
      annot['@type'] = 'oa:Annotation'
      annot['motivation'] = 'sc:painting'
      annot['resource'] = {}
      annot['resource']['@type'] = 'cnt:ContentAsText'
      annot['resource']['format'] = 'text/plain'
      text = []
      confidence = 0
      line.children.each do |str|
        if str.name == 'String'
          text << str['CONTENT'].force_encoding(encoding).encode('UTF-8')
          confidence += str['WC'].to_f
        end
      end
      annot['resource']['chars'] = text.join(' ')
      annot['metadata'] = {}
      annot['metadata']['word_confidence'] = text.size == 0 ? 0 : confidence / text.size
      annot['on'] = "<host>/iiif/#{doc_id}/canvas/page_#{page_num}#xywh=#{line['HPOS']},#{line['VPOS']},#{line['WIDTH']},#{line['HEIGHT']}"
      annotation_list['resources'] << annot
    end

    annotation_list['within'] = {}
    annotation_list['within']['@id'] = "<host>/iiif/#{doc_id}/layer/ocr_line_level"
    annotation_list['within']['@type'] = 'sc:Layer'
    annotation_list['within']['label'] = 'OCR Layer'
    annotation_list.to_json
  end

  def parse_alto_block(doc, doc_id, page_num, encoding)
    annotation_list = {}
    annotation_list['@context'] = 'http://iiif.io/api/presentation/2/context.json'
    annotation_list['@id'] = "<host>/iiif/#{doc_id}/list/page_#{page_num}_ocr_block_level"
    annotation_list['@type'] = 'sc:AnnotationList'
    annotation_list['resources'] = []

    doc.xpath('//TextBlock').each do |block|
      annot = {}
      annot['@type'] = 'oa:Annotation'
      annot['motivation'] = 'sc:painting'
      annot['resource'] = {}
      annot['resource']['@type'] = 'cnt:ContentAsText'
      annot['resource']['format'] = 'text/plain'
      text = []
      confidence = 0
      block.children.each do |line|
        if line.name == 'TextLine'
          line.children.each do |str|
            if str.name == 'String'
              text << str['CONTENT'].force_encoding(encoding).encode('UTF-8')
              confidence += str['WC'].to_f
            end
          end
        end
      end
      annot['resource']['chars'] = text.join(' ')
      annot['metadata'] = {}
      annot['metadata']['word_confidence'] = text.size == 0 ? 0 : confidence / text.size
      annot['on'] = "<host>/iiif/#{doc_id}/canvas/page_#{page_num}#xywh=#{block['HPOS']},#{block['VPOS']},#{block['WIDTH']},#{block['HEIGHT']}"
      annotation_list['resources'] << annot
    end

    annotation_list['within'] = {}
    annotation_list['within']['@id'] = "<host>/iiif/#{doc_id}/layer/ocr_block_level"
    annotation_list['within']['@type'] = 'sc:Layer'
    annotation_list['within']['label'] = 'OCR Layer'
    annotation_list.to_json
  end
}