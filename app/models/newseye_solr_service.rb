class NewseyeSolrService

  def self.get_by_id(id)
    ActiveFedora::SolrService.get("id:#{id}")['response']['docs'][0]
  end

  def self.get_annots_from_page(id, level)
    flarg = "*, [child parentFilter=level:1.* childFilter=level:#{level} limit=1000000]"
    ActiveFedora::SolrService.query("id:#{id}", {fl: flarg}).first['_childDocuments_']
  end

  def self.get_entities_annots_from_page(pageid)
    numpage = pageid.split('_')[-1]
    issueid = pageid[0...pageid.index('_page_')]
    output = []
    ActiveFedora::SolrService.query("id:entity_* AND doc_id_ssi:#{issueid}", rows: 100000).map do |solr_res|
      puts solr_res
      output << {mention: solr_res['mention_ssi'], selectors: solr_res['selector_ssim'].select { |selector| selector.include? "/canvas/page_#{numpage}"}}
    end
    output
  end

  # @@connection = false
  #
  # def self.connect
  #   @@connection = RSolr.connect(url: Rails.configuration.solr['url'])
  #   @@connection
  # end
  #
  # def self.add(params)
  #   connect unless @@connection
  #   @@connection.add(params)
  # end
  #
  # def self.get_by_id(id)
  #   connect unless @@connection
  #   @@connection
  # end
  #
  # def self.commit
  #   connect unless @@connection
  #   @@connection.commit
  # end

end