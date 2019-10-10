require 'newseye/newseye_solr_mapper'

Solrizer::FieldMapper.descriptors = [NewseyeSolrMapper, Solrizer::DefaultDescriptors]

# Blacklight::RequestBuilders.class_eval do
#   def search_builder_class
#     SearchBuilderIds
#   end
# end
Blacklight::SearchHelper.class_eval do
  def repository
    Blacklight::Solr::Repository.new(Blacklight::Configurable.default_configuration)
  end
end