class NewseyeSolrService

  def self.get_by_id(id)
    connect unless @@connection
    @@connection.get('select', params: {q:"id:#{id}"})['response']['docs'][0]
  end

  def self.get_articles_ids_from_issue_id id
    connect unless @@connection
    @@connection.get('select', params: {q:"from_issue_ssi:#{id} AND has_model_ssim:Article", fl:"id", rows:100000000})['response']['docs'].map {|o| o['id']}
  end

  def self.get_issues_ids_from_newspaper_id id
    connect unless @@connection
    @@connection.get('select', params: {q:"member_of_collection_ids_ssim:#{id} AND has_model_ssim:Issue", fl:"id", rows:100000000})['response']['docs'].map {|o| o['id']}
  end

  def self.get_url_from_id id
    NewseyeSolrService.query({q: "*:*", fq: ["id:#{id}"], fl: "original_uri_ss", rows: 1})[0]['original_uri_ss']
  end

  def self.get_newspapers
    connect unless @@connection
    @@connection.get('terms', params: {'terms.fl': "member_of_collection_ids_ssim", 'terms.limit': 100})['terms']['member_of_collection_ids_ssim'].select{|k| k.is_a? String }
  end

  def self.get_min_max_dates
    connect unless @@connection
    res = @@connection.get('select', params: {q: "*:*", fq: ["has_model_ssim:Issue"], rows: 0, stats: true, "stats.field": "year_isi"})
    [ res['stats']['stats_fields']['year_isi']['min'].to_i, res['stats']['stats_fields']['year_isi']['max'].to_i ]
  end

  def self.get_facets_counts
    connect unless @@connection
    res = @@connection.get('select', params: {
        q: "*:*",
        fq: ["has_model_ssim:(Issue OR Article)"],
        rows: 0,
        "facet.field": ["language_ssi", "date_created_dtsi", "month_isi", "day_isi", "member_of_collection_ids_ssim", "has_model_ssim", "linked_person_ssim", "linked_location_ssim", "linked_organisations_ssim"]})
    res[:response]
  end

  def self.get_nb_issues_per_year
    nps = NewseyeSolrService.get_newspapers
    connect unless @@connection
    out = {}
    nps.each do |npid|
      params = {q: '*:*', fq: ["member_of_collection_ids_ssim:#{npid}", "has_model_ssim:Issue"],
                'facet.range': 'date_created_dtsi',
                'f.date_created_dtsi.facet.range.start': '1850-01-01T00:00:00.000Z',
                'f.date_created_dtsi.facet.range.end': '1950-01-01T00:00:00.000Z',
                'f.date_created_dtsi.facet.range.gap': '+1YEAR',
                'facet.mincount': 0,
                rows: 0}
      res = @@connection.get('select', params: params)
      out[npid] = res['facet_counts']['facet_ranges']['date_created_dtsi']['counts'].in_groups_of(2)
    end
    out
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
    mentions = NewseyeSolrService.query({q: '*:*', fq: ["doc_id_ssi:#{issueid}", "{!cache=false cost=200}selector_ssim:*page_#{numpage}#*"], rows: 100000})
    # puts "### #{mentions.size}"
    mentions.map do |solr_res|
      output << {mention: solr_res['mention_ssi'], selectors: solr_res['selector_ssim'].select { |selector| selector.include? "/canvas/page_#{numpage}"}}
    end
    output
  end

  @@connection = false

  def self.query params
    connect unless @@connection
    # @@connection.get('select', params: params)['response']['docs']
    @@connection.send_and_receive("select", data: params, method: :post)['response']['docs']
  end

  def self.connect
    @@connection = RSolr.connect(url: Rails.configuration.solr['url']) unless @@connection
    @@connection
  end

  def self.add(params)
    connect unless @@connection
    @@connection.add(params)
  end

  def self.update(params)
    connect unless @@connection
    @@connection.update(params)
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