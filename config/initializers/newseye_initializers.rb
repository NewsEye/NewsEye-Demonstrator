require 'newseye/newseye_solr_mapper'

Solrizer::FieldMapper.descriptors = [NewseyeSolrMapper, Solrizer::DefaultDescriptors]