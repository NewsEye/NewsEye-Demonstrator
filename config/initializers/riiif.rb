# Riiif::Image.file_resolver.base_path = '/home/axel/data_bruxelles/'

# Tell RIIIF to get files via HTTP (not from the local disk)
# Riiif::Image.file_resolver = Riiif::HTTPFileResolver.new
#
# # This tells RIIIF how to resolve the identifier to a URI in Fedora
# Riiif::Image.file_resolver.id_to_uri = lambda do |id|
#   pfs = PageFileSet.find(id)
#   if pfs.original_file
#     pfs.original_file.uri.to_s
#   else
#     pfs.iiif_url
#   end
#   # ActiveFedora::Base.id_to_uri(CGI.unescape(id)).tap do |url|
#   #   logger.info "Riiif resolved #{id} to #{url}"
#   # end
# end

# In order to return the info.json endpoint, we have to have the full height and width of
# each image. If you are using hydra-file_characterization, you have the height & width
# cached in Solr. The following block directs the info_service to return those values:
# Riiif::Image.info_service = lambda do |id, file|
#   # id will look like a path to a pcdm:file
#   # (e.g. rv042t299%2Ffiles%2F6d71677a-4f80-42f1-ae58-ed1063fd79c7)
#   # but we just want the id for the FileSet it's attached to.
#
#   # Capture everything before the first slash
#   fs_id = id.sub(/\A([^\/]*)\/.*/, '\1')
#   resp = ActiveFedora::SolrService.get("id:#{fs_id}")
#   doc = resp['response']['docs'].first
#   raise "Unable to find solr document with id:#{fs_id}" unless doc
#
#   # You’ll want default values if you make thumbnails of PDFs or other
#   # file types that `identify` won’t return dimensions for
#   {
#       height: doc["height_is"] || 100,
#       width: doc["width_is"] || 100,
#       format: doc["mime_type_ssi"],
#   }
# end

# def logger
#   Rails.logger
# end

# Note that this is translated to an `expires` argument to the
# ActiveSupport::Cache::Store in use, by default the host application's
# Rails.cache. Some cache stores may not automatically purge expired content,
# such as the default FileStore.
# http://guides.rubyonrails.org/caching_with_rails.html#cache-stores
Riiif::Engine.config.cache_duration = 30.days