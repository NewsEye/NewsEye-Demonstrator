class NewseyeSolrService

  def self.get_by_id(id)
    connect unless @@connection
    @@connection.get('select', params: {q:"id:#{id}"})['response']['docs'][0]
  end

  def self.get_articles_ids_from_issue_id id
    connect unless @@connection
    @@connection.get('select', params: {q:"id:#{id}_article_*", fl:"id", rows:100000000})['response']['docs'].map {|o| o['id']}
  end

  def self.get_issues_ids_from_newspaper_id id
    connect unless @@connection
    @@connection.get('select', params: {q:"id:#{id}* AND has_model_ssim:Issue", fl:"id", rows:100000000})['response']['docs'].map {|o| o['id']}
  end

  # def self.get_annots_from_page(id, level)
  #   flarg = "*, [child parentFilter=level:1.* childFilter=level:#{level} limit=1000000]"
  #   ActiveFedora::SolrService.query("id:#{id}", {fl: flarg}).first['_childDocuments_']
  # end
  #
  #
  def self.get_entities_annots_from_page(pageid)
    numpage = pageid.split('_')[-1]
    issueid = pageid[0...pageid.index('_page_')]
    output = []
    NewseyeSolrService.query({q: "id:entity_* AND doc_id_ssi:#{issueid}", rows: 100000}).map do |solr_res|
      puts solr_res
      output << {mention: solr_res['mention_ssi'], selectors: solr_res['selector_ssim'].select { |selector| selector.include? "/canvas/page_#{numpage}"}}
    end
    output
  end

  @@connection = false

  def self.query params
    connect unless @@connection
    @@connection.get('select', params: params)['response']['docs']
  end

  def self.connect
    @@connection = RSolr.connect(url: Rails.configuration.solr['url']) unless @@connection
    @@connection
  end

  def self.add(params)
    connect unless @@connection
    @@connection.add(params)
  end
  #
  # def self.get_by_id(id)
  #   connect unless @@connection
  #   @@connection
  # end
  #
  def self.commit params={}
    connect unless @@connection
    @@connection.commit params
  end

end