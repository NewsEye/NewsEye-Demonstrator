parse_iob()

BEGIN {
  def parse_iob
    iob_file = "/home/axel/Bureau/test_doc3_output.txt"
    content = File.read(iob_file)
    lines = content.split("\n")
    tokens = []
    lines.each { |line| tokens.push(*line.split(' ')) }
    puts tokens.size

    fulltext = Issue.find('paivalehti_471957').all_text
# puts fulltext

    chars_counter_begin = 0
    chars_counter_end = 0
    named_entities = []
    ind = 0
    while ind < tokens.size
      token, tag = tokens[ind].split(/__([IOB])/)
      chars_counter_begin = ind == 0 ? 0 : chars_counter_end + 1
      chars_counter_end = chars_counter_begin + token.size
      # puts "(#{token})\t->\t\"#{fulltext[chars_counter_begin...chars_counter_end]}\"\t#{chars_counter_begin}..#{chars_counter_end}"
      if tag == 'O'
        ind += 1
        next
      end

      if tag.start_with? ('B')
        mention_label = token
        next_token, next_tag = tokens[ind+1].split(/__([IOB])/)
        while next_tag.start_with? 'I'
          ind += 1
          chars_counter_end += next_token.size + 1 ##############################################################
          mention_label += " #{next_token}"
          next_token, next_tag = tokens[ind+1].split(/__([IOB])/)
        end
        puts "#{mention_label} : #{fulltext[chars_counter_begin..chars_counter_end]}"
        named_entities << {mention: mention_label, ne_type: tag.split('-')[1], pos: {start: chars_counter_begin, end: chars_counter_end}}
      end


      ind += 1
    end

    word_annots = get_word_annots('paivalehti_471957')
    named_entities.each do |ne|
      puts ne[:mention]
      ne_start = ne[:pos][:start]
      ne_end = ne[:pos][:end]
      puts fulltext[ne_start..ne_end]
      annots = map_fulltext_iiif(word_annots, ne_start, ne_end)
      puts annots
      # entity_link = NamedEntity.where(ne_type: ne[:ne_type]).first
      # NamedEntityMention.create(mention: ne[:mention], doc_id: 'paivalehti_471957', named_entity: entity_link,
      #                           detection_confidence: 0, linking_confidence: 0, stance: 0, position: ne[:pos], iiif_annotations: annots)
    end
  end

  def map_fulltext_iiif(word_annots, start_pos, end_pos)
    cpt = 0
    annots = []
    word_annots.each do |wa|
      if cpt >= start_pos and cpt < end_pos
        annots << wa['on']
      end
      cpt += wa['resource']['chars'].size+1
    end
    return annots
  end

  def get_word_annots(issue_id)
    i = Issue.find(issue_id)
    word_annots = []
    i.pages.each do |p|
      data = JSON.parse(p.ocr_word_level_annotation_list.content)
      word_annots.push(*data['resources'])
    end
    word_annots
  end
}