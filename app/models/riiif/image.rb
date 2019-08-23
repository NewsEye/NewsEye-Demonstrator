require 'digest/md5'

module Riiif
  class Image
    extend Deprecation

    class_attribute :file_resolver, :info_service, :authorization_service, :cache
    self.file_resolver = Riiif::MyFileSystemFileResolver.new
    self.authorization_service = NilAuthorizationService
    self.cache = Rails.cache
    self.info_service = lambda do |id, file|
      pfs = PageFileSet2.from_solr id
      raise "Unable to find solr document with id:#{fs_id}" unless pfs
      {
          height: pfs.height || 100,
          width: pfs.width || 100,
          format: pfs.mime_type,
      }
    end

    # this is the default info service
    # returns a hash with the original image dimensions.
    # You can set your own lambda if you want different behavior
    # example:
    #   {:height=>390, :width=>600}
    # self.info_service = lambda do |id, image|
    #   cache.fetch(cache_key(id, info: true), compress: true, expires_in: expires_in) do
    #     image.info
    #   end
    # end
    # self.info_service = lambda do |id, file|
    #   fs_id = id.sub(/\A([^\/]*)\/.*/, '\1')
    #   resp = ActiveFedora::SolrService.get("id:#{fs_id}")
    #   doc = resp['response']['docs'].first
    #   raise "Unable to find solr document with id:#{fs_id}" unless doc
    #   {
    #       height: doc["height_is"] || 100,
    #       width: doc["width_is"] || 100,
    #       format: doc["mime_type_ssi"],
    #   }
    # end

    attr_reader :id

    # @param [String] id The identifier of the file to be looked up.
    # @param [Riiif::File] file Optional: The Riiif::File to use instead of looking one up.
    def initialize(id, passed_file = nil)
      @id = id
      @file = passed_file if passed_file.present?
    end

    def file
      @file ||= file_resolver.find(id)
    end

    alias image file
    deprecation_deprecate image: 'Use Image#file instead. This will be removed in riiif 2.0'

    ##
    # @param [ActiveSupport::HashWithIndifferentAccess] args
    # @return [String] the image data
    def render(args)
      cache_opts = args.select { |a| %w(region size quality rotation format).include? a.to_s }
      key = Image.cache_key(id, cache_opts)

      cache.fetch(key, compress: true, expires_in: Image.expires_in) do
        file.extract(IIIF::Image::OptionDecoder.decode(args), info)
      end
    end

    def info
      @info ||= begin
                  result = info_service.call(id, file)
                  ImageInformation.new(
                    width: result[:width],
                    height: result[:height],
                    format: result[:format]
                  )
                end
    end

    class << self
      def expires_in
        if Riiif::Engine.config.respond_to?(:cache_duration_in_days)
          Deprecation.warn(self,
                           'Riiif::Engine.config.cache_duration_in_days is deprecated; '\
                           'use #cache_duration instead and pass a fully-qualified date (e.g., `3.days`)')
          Riiif::Engine.config.cache_duration_in_days.days
        else
          Riiif::Engine.config.cache_duration
        end
      end

      def cache_key(id, options)
        str = options.to_h.merge(id: id)
                     .delete_if { |_, v| v.nil? }
                     .sort_by { |k, _v| k.to_s }
                     .to_s

        # Use a MD5 digest to ensure the keys aren't too long, and a prefix
        # to avoid collisions with other components in shared cache.
        'riiif:' + Digest::MD5.hexdigest(str)
      end
    end
  end
end
