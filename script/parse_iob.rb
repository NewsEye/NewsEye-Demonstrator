parse_iob()

BEGIN {
  def parse_iob

    ids = Issue.where(member_of_collection_ids_ssim: 'l_oeuvre').map(&:id)
    ids.each_with_index do |issueid, idx|
      puts "Importing named entities #{idx + 1} out of #{ids.size}"

      iob_file = "/home/axel/data_l_oeuvre_ahmed/fr_outputs/#{issueid}.txt"
      content = File.read(iob_file)
      lines = content.split("\n")
      tokens = []
      lines.each { |line| tokens.push(*line.split(' ')) }
      # puts tokens.size

      fulltext = Issue.find(issueid).all_text
  # puts fulltext

      chars_counter_begin = 0
      chars_counter_end = 0
      named_entities = []
      ind = 0
      while ind < tokens.size
        token, tag = tokens[ind].split(/__(?=[IOB])/)
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
          named_entities << {mention: mention_label, ne_type: tag.split('-')[1], pos: {start: chars_counter_begin, end: chars_counter_end}}
        end


        ind += 1
      end

      word_annots = get_word_annots(issueid)
      nems = map_fulltext_iiif_all(word_annots, named_entities, issueid)
      NamedEntityMention.batch_index(nems)
      # named_entities.each do |ne|
      #   puts ne[:mention] + " [" + ne[:ne_type] + "]"
      #   ne_start = ne[:pos][:start]
      #   ne_end = ne[:pos][:end]
      #   puts fulltext[ne_start..ne_end]
      #   annots = map_fulltext_iiif(word_annots, ne_start, ne_end)
      #   puts annots
      #   #############################################################################################
      #   case ne[:ne_type]
      #   when 'LIEU'
      #     entity_link = NamedEntity.where(ne_type: 'Location').first
      #   when 'PERS'
      #     entity_link = NamedEntity.where(ne_type: 'Person').first
      #   when 'ORG'
      #     entity_link = NamedEntity.where(ne_type: 'Organization').first
      #   end
      #   #############################################################################################
      #   NamedEntityMention.create(mention: ne[:mention], doc_id: 'l_oeuvre_12148-bpt6k4613644p', named_entity: entity_link,
      #                             detection_confidence: 0, linking_confidence: 0, stance: 0, position: ne[:pos], iiif_annotations: annots)
      # end
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

  def map_fulltext_iiif_all(word_annots, named_entities, doc_id)
    # sort ne by pos[start]
    nems = []
    ne_ind = 0
    cpt = 0
    annots = []
    word_annots.each do |wa|
      if cpt > named_entities[ne_ind][:pos][:end]
        case named_entities[ne_ind][:ne_type]
        when 'LIEU'
          entity_link = NamedEntity.where(ne_type: 'Location').first
        when 'PERS'
          entity_link = NamedEntity.where(ne_type: 'Person').first
        when 'ORG'
          entity_link = NamedEntity.where(ne_type: 'Organization').first
        end
        nems << NamedEntityMention.create(mention: named_entities[ne_ind][:mention], doc_id: doc_id,
                                  named_entity: entity_link, detection_confidence: 0, linking_confidence: 0, stance: 0,
                                  position: named_entities[ne_ind][:pos], iiif_annotations: annots)
        # puts named_entities[ne_ind][:mention] + " [" + named_entities[ne_ind][:ne_type] + "]"
        # # puts fulltext[named_entities[ne_ind][:pos][:start]..named_entities[ne_ind][:pos][:end]]
        # puts annots
        print "#{named_entities[ne_ind][:mention] + " [" + named_entities[ne_ind][:ne_type] + "]"}\n#{annots}\r\b\r"
        ne_ind += 1
        annots = []
        return nems if ne_ind > named_entities.size - 1
      end
      if cpt >= named_entities[ne_ind][:pos][:start] and cpt < named_entities[ne_ind][:pos][:end]
        annots << wa['on']
      end
      cpt += wa['resource']['chars'].size+1
    end
    nems
  end

  def get_word_annots(issue_id)
    i = Issue.find(issue_id)
    word_annots = []
    i.pages.each do |p|
      # data = JSON.parse(p.ocr_word_level_annotation_list.content)
      data = p.generate_word_annotation_list
      word_annots.push(*data['resources'])
    end
    word_annots
  end
}