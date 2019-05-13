iob_file = "/home/axel/Bureau/test_doc_output.txt"
content = File.read(iob_file)
lines = content.split("\n")
tokens = []
lines.each { |line| tokens.push(*line.split(' ')) }
puts tokens.size

named_entities = []
ind = 0
while ind < tokens.size
  token, tag = tokens[ind].split('__')

  if tag == 'O'
    ind += 1
    next
  end

  if tag.start_with? ('B')
    mention_label = token
    next_token, next_tag = tokens[ind+1].split('__')
    while next_tag.start_with? 'I'
      ind += 1
      mention_label += " #{next_token}"
      next_token, next_tag = tokens[ind+1].split('__')
    end
    named_entities << {mention: mention_label, ne_type: tag.split('-')[1]}
  end


  ind += 1
end
named_entities.each do |ne|
  entity_link = NamedEntity.where(ne_type: ne[:ne_type]).first
  NamedEntityMention.create(mention: ne[:mention], doc_id: 'paivalehti_471957', named_entity: entity_link,
                            detection_confidence: 0, linking_confidence: 0, stance: 0)
end