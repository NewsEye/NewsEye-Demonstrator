require 'open-uri'
require 'json'
require 'sparql/client'

def get_tokens_offset text
  tokens = []
  text.gsub("\n", " ").scan(/\S+/) { tokens << [$~.begin(0), $~.end(0), $~.to_s] }
  tokens
end

def map_articles(articles, original_text)
  articles_offset = {}
  articles.each do |id, text|
    start_ind = original_text.index(text)
    end_ind = start_ind.nil? ? nil : start_ind + text.size
    articles_offset[id] = [start_ind, end_ind]
  end
  articles_offset
end

def get_article_id_from_ne_offset(articles_offset, ne_offset_start)
  articles_offset.each do |id, art_offset|
    next if art_offset[0].nil?
    return id if ne_offset_start >= art_offset[0] and ne_offset_start < art_offset[1]
  end
  nil
end

def get_labels_from_wikidata_url url
  entity_id = url.split("/")[-1]
  sparql = <<~HEREDOC.strip
    SELECT * WHERE {
      wd:#{entity_id} rdfs:label ?label 
    }
  HEREDOC
  endpoint = "https://query.wikidata.org/sparql"
  client = SPARQL::Client.new(endpoint, :method => :get, :headers => { 'User-Agent': 'NewsEyeAgent'})
  rows = client.query(sparql)
  labels = {}
  rows.each do |row|
    label = row[:label].to_s.strip
    label = label.split(":")
    label = label[1..-1].join(":") if label.size > 1
    labels[row[:label].language.to_s] = label
  end
  labels
end

def combine_NER_NEL_files
  ner_dir = "/home/axel/Téléchargements/NEL_01_2020/NewsEyeNER_stance"
  nel_dir = "/home/axel/Téléchargements/NEL_01_2020/arbeiterzeitung-nel-conlls"
  out_dir = "/home/axel/Téléchargements/NEL_01_2020/arbeiter_zeitung_combined"
  puts Dir["#{ner_dir}/*.txt"].size
  puts Dir["#{nel_dir}/*.txt.conll"].size
  Dir["#{ner_dir}/*.txt"].each_with_index do |file, idx|
    puts idx
    ner_file = "#{ner_dir}/#{file.split("/")[-1][0..-5]}.txt"
    nel_file = "#{nel_dir}/#{file.split("/")[-1][0..-5]}.txt.conll"
    out_file = "#{out_dir}/#{file.split("/")[-1][0..-5]}.txt"
    to_write = []
    nerlines = []
    nellines = []
    File.open(ner_file, 'r') do |nerf|
      nerlines = nerf.read.split("\n")
    end
    File.open(nel_file, 'r') do |nelf|
      nellines = nelf.read.split("\n")
    end
    nerlines.each_with_index do |nerline, lineidx|
      nelline = nellines[lineidx]
      token, tag, nel = nelline.split("\t")
      token, tag, stance = nerline.split("\t")
      outline = "#{token}\t#{tag}" if stance.nil?
      outline = "#{token}\t#{tag}\t#{nel}\t#{stance}" unless stance.nil?
      to_write << outline
    end
    File.open(out_file, 'w') do |outf|
      outf.write to_write.join("\n")
    end
  end
end

def process_issue(issue_id, conll_path, language, solr_endpoint, save_dir)

  ids_query = "#{solr_endpoint}/select?q=id:#{issue_id}&fl=all_text_t#{language}_siv"
  original_text = JSON.parse(open(ids_query).read)['response']['docs'][0]["all_text_t#{language}_siv"]
  original_tokens = get_tokens_offset original_text
  puts original_tokens.size

  articles_query = "#{solr_endpoint}/select?q=*:*&fq=has_model_ssim:Article&fq=from_issue_ssi:#{issue_id}&fl=id,all_text_t#{language}_siv&rows=100000"
  articles = JSON.parse(open(articles_query).read)['response']['docs'].map {|d| [d['id'], d["all_text_t#{language}_siv"]] }.to_h
  articles_offset = map_articles articles, original_text

  conll = File.open(conll_path).read
  conll_lines = conll.split("\n")
  puts conll_lines.size


  chars_counter_begin = 0
  chars_counter_end = 0
  named_entities = []
  ind = 0
  while ind < conll_lines.size
    token, tag, link, stance = conll_lines[ind].split("\t")
    chars_counter_begin = ind == 0 ? 0 : chars_counter_end + 1
    chars_counter_end = chars_counter_begin + token.size
    if tag == 'O'
      ind += 1
      next
    end

    if tag.start_with? ('B')
      entity_tokens_idx = [ind]
      mention_label = token
      next_token, next_tag, next_link, next_stance = conll_lines[ind+1].split("\t")
      while next_tag.start_with? 'I'
        ind += 1
        entity_tokens_idx << ind
        chars_counter_end += next_token.size + 1
        mention_label += " #{next_token}"
        next_token, next_tag, next_link, next_stance = conll_lines[ind+1].split("\t")
      end
      startpos = original_tokens[entity_tokens_idx.min][0]
      endpos = original_tokens[entity_tokens_idx.max][1]
      named_entities << {mention: mention_label, ne_type: tag.split('-')[1], pos: {start: startpos, end: endpos}, link: link.strip, stance: stance.strip}
    end
    ind += 1
  end
  stance_map = {"NEG" => -1, "OBJ" => 0, "POS" => 1}
  ne_to_index = []
  named_entities.each_with_index do |ne, ne_idx|
    puts "iob_mention: #{ne[:mention]}"
    puts "original_text_mention: #{original_text[ne[:pos][:start]..ne[:pos][:end]]}"
    puts "ne_type: #{ne[:ne_type]}"
    puts "stance: #{ne[:stance]}" # POS, NEG or OBJ
    if ne[:link] != "NIL"
      linked_ne_type = ne[:ne_type].gsub "LIEU", "LOC"
      #puts "kb_link: #{ne[:link]}" # link or NIL
      linked_ne_id = "entity_#{linked_ne_type}_#{ne[:link].split('/')[-1]}"
      #ne_to_index << linked_entity
    else
      linked_ne_id = nil
    end
    entity_mention = NamedEntityMention.new
    entity_mention.id = "entity_mention_#{issue_id}_#{ne_idx}"
    entity_mention.ne_type = ne[:ne_type].gsub "LIEU", "LOC"
    entity_mention.linked_entity_id = linked_ne_id
    entity_mention.stance = stance_map[ne[:stance]]
    entity_mention.mention = ne[:mention]
    entity_mention.issue_id = issue_id
    entity_mention.issue_position = {start: ne[:pos][:start], end: ne[:pos][:end]}
    entity_mention.article_position = {start: nil, end: nil}
    article_id = get_article_id_from_ne_offset(articles_offset, ne[:pos][:start])
    unless article_id.nil?
      puts "in_article: #{article_id}" # article_id or nil
      ne_article_offset = [ne[:pos][:start]-articles_offset[article_id][0], ne[:pos][:end]-articles_offset[article_id][0]]
      puts [ne_article_offset[0]..ne_article_offset[1]]
      puts "article_mention: #{articles[article_id][ne_article_offset[0]..ne_article_offset[1]]}" # article_id or nil
      entity_mention.article_id = article_id
      entity_mention.article_position = {start: ne_article_offset[0], end: ne_article_offset[1]}
    end
    ne_to_index << entity_mention
    puts "###"
  end
  json_data = ne_to_index.map(&:to_solr)
  File.open("#{save_dir}/#{issue_id}_entities.json", 'w') do |f| f.write json_data.to_json end
  puts NewseyeSolrService.add json_data
  puts NewseyeSolrService.commit
end

def index_linked_entities(solr_endpoint, save_dir)
  query = "#{solr_endpoint}/select?q=*:*&fq=linked_entity_ssi:*&facet.field=linked_entity_ssi&facet=on&facet.limit=999999&rows=0&start=0"
  linked_entities_ids = JSON.parse(open(query).read)['facet_counts']['facet_fields']["linked_entity_ssi"].select.with_index do |id, idx|
    idx.even? and id != ""
  end
  indexed_linked_entities_query = "#{solr_endpoint}/select?q=*:*&fq=kb_url_ssi:*&fl=id&rows=10000000"
  already_indexed = JSON.parse(open(indexed_linked_entities_query).read)['response']['docs'].map{|doc| doc['id']}
  ids_to_index = linked_entities_ids - already_indexed
  to_index = []
  ids_to_index.each_with_index do |ne_id, idx|
    puts "Getting entity #{idx+1} out of #{ids_to_index.size}"
    e, ne_type, wiki_id = ne_id.split("_")
    kb_url = "https://www.wikidata.org/wiki/#{wiki_id}"
    linked_entity_labels = get_labels_from_wikidata_url kb_url
    linked_entity = NamedEntity.new
    linked_entity.id = ne_id
    linked_entity.ne_type = ne_type
    linked_entity.labels = linked_entity_labels
    linked_entity.kb_url = kb_url
    to_index << linked_entity
  end
  unless to_index.empty?
    json_data = to_index.map(&:to_solr)
    File.open("#{save_dir}/#{Time.now.to_i}.json", 'w') do |f| f.write json_data.to_json end
    puts NewseyeSolrService.add json_data
    puts NewseyeSolrService.commit
  end
end

def get_linked_entities(solr_endpoint, issue_or_article_id)
  fq = []
  fq << "linked_entity_ssi:*" # to get entity mentions (only them contain this field)
  fq << "-linked_entity_ssi:\"\"" # to get only mentions that are linked
  fq << "issue_id_ssi:#{issue_or_article_id}" if issue_or_article_id.index("_article_").nil?
  fq << "article_id_ssi:#{issue_or_article_id}" unless issue_or_article_id.index("_article_").nil?
  query = "#{solr_endpoint}/select?q=*:*&#{fq.map{ |filter| "fq=#{filter}" }.join('&')}&fl=linked_entity_ssi&rows=100000"
  linked_entities_ids = JSON.parse(open(query).read)['response']['docs'].map{|doc| doc['linked_entity_ssi']}
end

def add_entities_to_issues_and_articles(solr_endpoint, issue_or_article_id)
  linked_entities = get_linked_entities(solr_endpoint, issue_or_article_id)
  json_doc = {}
  json_doc['id'] = issue_or_article_id
  json_doc['linked_entities_ssim'] = {set: linked_entities}
  ###############""
  # ###############""
  # ################"
  json_doc['linked_persons_ssim'] = {set: linked_entities.select{|ne| !ne.index("entity_PERS").nil?}}
  json_doc['linked_locations_ssim'] = {set: linked_entities.select{|ne| !ne.index("entity_LOC").nil?}}
  json_doc['linked_organisations_ssim'] = {set: linked_entities.select{|ne| !ne.index("entity_ORG").nil?}}


  #json_docs = json_docs.map{ |jd| "\"add\": {\"doc\": #{jd.to_json} }" }
  #data = "{#{json_docs.join(",")}}"
  uri = URI.parse("#{solr_endpoint}/update")
  http = Net::HTTP.new(uri.host, uri.port)
  header = {'Content-Type': 'application/json'}
  data = "{\"add\": {\"doc\": #{json_doc.to_json}}}"
  request = Net::HTTP::Post.new(uri.request_uri, header)
  request.body = data
  puts JSON.parse(http.request(request).response.body)

  commit_uri = URI.parse("#{solr_endpoint}/update?commit=true")
  puts JSON.parse(http.request(Net::HTTP::Get.new(commit_uri.request_uri, header)).response.body)

  #puts NewseyeSolrService.update(data: [json_doc].to_json, headers: { 'Content-Type' => 'application/json' })
  #puts NewseyeSolrService.commit
end
#combine_NER_NEL_files

#save_dir = "/home/axel/solr_backup/arbeiter_zeitung_entities"
#issue_id = "arbeiter_zeitung_aze19371023"
#conll_path = "/home/axel/Téléchargements/NEL_01_2020/arbeiter_zeitung_combined/arbeiter_zeitung_aze19371023.txt"
save_dir = "/home/axel/solr_backup/l_oeuvre_entities"
issue_id = "l_oeuvre_12148-bpt6k4616743j"
conll_path = "/home/axel/Téléchargements/NEL_01_2020/NewsEye_fr_combine_output_Ner_Nel_Stance/l_oeuvre_12148_bpt6k4616743j.txt"

linked_entities_save_dir = "/home/axel/solr_backup/linked_entities"
solr_endpoint = "http://localhost:8983/solr/hydra-development"
#process_issue(issue_id, conll_path, "fr", solr_endpoint, save_dir)
#index_linked_entities solr_endpoint, linked_entities_save_dir
add_entities_to_issues_and_articles solr_endpoint, issue_id
articles_query = "#{solr_endpoint}/select?q=*:*&fq=has_model_ssim:Article&fq=from_issue_ssi:#{issue_id}&fl=id&rows=100000"
articles = JSON.parse(open(articles_query).read)['response']['docs'].map {|d| d["id"] }
articles.each do |artid| add_entities_to_issues_and_articles(solr_endpoint, artid) end