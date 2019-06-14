class PageFileSet < ActiveFedora::Base

  include Hydra::Works::FileSetBehavior

  attr_accessor :to_solr_annots, :annot_hierarchy, :language

  def initialize
    super
    self.to_solr_annots = false
    self.annot_hierarchy = []
  end

  property :page_number, predicate: ::RDF::Vocab::SCHEMA.pagination, multiple: false do |index|
    index.as :int_searchable
  end
  property :width, predicate: ::RDF::Vocab::MA.frameWidth, multiple: false do |index|
    index.as :int_stored
  end
  property :height, predicate: ::RDF::Vocab::MA.frameHeight, multiple: false do |index|
    index.as :int_stored
  end
  property :mime_type, predicate: ::RDF::Vocab::DC11.format, multiple: false do |index|
    index.as :string_searchable_uniq
  end
  property :iiif_url, predicate: ::RDF::Vocab::SCHEMA.image, multiple: false do |index|
    index.as :string_stored_uniq
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
    ActiveFedora::SolrService.query("id:#{doc_id}_page_#{page_num}", {fl: flarg}).first['_childDocuments_'].each do |annot|
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
    solr_doc = super
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

end