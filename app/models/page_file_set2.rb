class PageFileSet2

  # include Hydra::Works::FileSetBehavior

  attr_accessor :id, :page_number, :width, :height, :mime_type, :iiif_url, :level,
                :to_solr_annots, :annot_hierarchy, :language, :ocr_path, :image_path

  def initialize
    super
    self.to_solr_annots = false
    self.annot_hierarchy = []
  end

  def canvas(host, issue_id, with_annotations)
    canvas = IIIF::Presentation::Canvas.new()
    canvas['@id'] = "#{host}/iiif/#{issue_id}/canvas/page_#{self.page_number}"
    canvas.width = self.width.to_i
    canvas.height = self.height.to_i
    canvas.label = self.page_number.to_s
    image_annotation = IIIF::Presentation::Annotation.new
    service = self.iiif_url #== nil ? "#{host}/iiif/#{issue_id}_page_#{self.page_number}" : self.iiif_url
    img_res_params = {
        service_id: service,
        profile: "http://iiif.io/api/image/2/level2.json",
        width: self.width.to_i,
        height: self.height.to_i
    }
    img_res = IIIF::Presentation::ImageResource.create_image_api_image_resource(img_res_params)
    img_res['@id'] = "#{issue_id}_page_#{self.page_number}"
    img_res.format = 'image/jpeg'
    image_annotation.resource = img_res
    image_annotation['on'] = canvas['@id']
    canvas.images << image_annotation

    if with_annotations
      ['word', 'line', 'block'].each do |level|
        anno_list = IIIF::Presentation::AnnotationList.new
        anno_list['@id'] = "#{host}/iiif/#{issue_id}/list/page_#{self.page_number}_ocr_#{level}_level"
        canvas.other_content << anno_list
      end
    end
    canvas
  end

  def generate_word_annotation_list
    layer = 'word'
    doc_id = self.id[0...self.id.index('_page_')]
    page_num = self.page_number
    annotation_list = {}
    annotation_list['@context'] = 'http://iiif.io/api/presentation/2/context.json'
    annotation_list['@id'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/list/page_#{page_num}_ocr_#{layer}_level"
    annotation_list['@type'] = 'sc:AnnotationList'
    annotation_list['resources'] = []
    annotation_list['within'] = {}
    annotation_list['within']['@id'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/layer/ocr_#{layer}_level"
    annotation_list['within']['@type'] = 'sc:Layer'
    annotation_list['within']['label'] = 'OCR Layer'
    level = case layer
            when 'word'
              '4.pages.blocks.lines.words'
            when 'line'
              '3.pages.blocks.lines'
            when 'block'
              '2.pages.blocks'
            else
              '*'
            end
    flarg = "*, [child parentFilter=level:1.* childFilter=level:#{level} limit=1000000]"
    NewseyeSolrService.query({q: "id:#{self.id}", fl: flarg}).first['_childDocuments_'].each do |annot|
      block_annot = {}
      block_annot['@type'] = 'oa:Annotation'
      block_annot['motivation'] = 'sc:painting'
      block_annot['resource'] = {}
      block_annot['resource']['@type'] = 'cnt:ContentAsText'
      block_annot['resource']['format'] = 'text/plain'
      block_annot['resource']['chars'] =  annot[annot.find{|k, hash| k.start_with?('text_')}[0]]
      block_annot['metadata'] = {}
      # block_annot['metadata']['word_confidence'] = block_text.size == 0 ? 0 : block_confidence / block_text.size
      block_annot['on'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/canvas/page_#{page_num}#{annot['selector']}"
      annotation_list['resources'] << block_annot
    end
    annotation_list
  end

  def to_solr
    solr_doc = {}
    solr_doc['id'] = self.id
    solr_doc['has_model_ssim'] = 'PageFileSet'
    solr_doc['page_number_isi'] = self.page_number
    solr_doc['width_isi'] = self.width
    solr_doc['height_isi'] = self.height
    solr_doc['mime_type_ssi'] = self.mime_type
    solr_doc['iiif_url_ss'] = self.iiif_url
    solr_doc['ocr_path_ss'] = self.ocr_path
    solr_doc['image_path_ss'] = self.image_path
    # solr_doc['member_ids'] = []
    # solr_doc['member_of_collection_ids'] = self.news

    if self.to_solr_annots
      solr_doc['level'] = '1.pages'
      solr_doc['_childDocuments_'] = []
      # language = Issue.find(self.id[0...self.id.rindex('_page_')]).language
      self.annot_hierarchy.each do |block|
        block["text_t#{self.language}_siv"] = block.delete('text')
        block['_childDocuments_'].each do |line|
          line["text_t#{self.language}_siv"] = line.delete('text')
          line['_childDocuments_'].each do |word|
            word["text_t#{self.language}_siv"] = word.delete('text')
          end
        end
        solr_doc['_childDocuments_'] << block
      end
    end
    solr_doc
  end

  def self.from_solr id
    attrs = NewseyeSolrService.get_by_id id
    p = PageFileSet2.new
    p.id = attrs['id']
    p.page_number = attrs['page_number_isi']
    p.width = attrs['width_isi']
    p.height = attrs['height_isi']
    p.mime_type = attrs['mime_type_ssi']
    p.iiif_url = attrs['iiif_url_ss']
    p.ocr_path = attrs['ocr_path_ss']
    p.image_path = attrs['image_path_ss'] if attrs['image_path_ss']
    p
  end

end