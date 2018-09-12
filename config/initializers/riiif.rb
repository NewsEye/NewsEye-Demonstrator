Riiif::Image.file_resolver = Riiif::HTTPFileResolver.new
Riiif::Image.file_resolver.cache_path = 'tmp/cache/riiif'