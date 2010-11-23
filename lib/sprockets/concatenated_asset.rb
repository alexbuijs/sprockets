require "digest/md5"
require "tilt"

module Sprockets
  class ConcatenatedAsset
    attr_reader :environment, :content_type, :format_extension, :mtime
    attr_reader :source_paths, :source

    def initialize(environment, pathname)
      @environment      = environment
      @content_type     = pathname.content_type
      @format_extension = pathname.format_extension
      @mtime            = Time.at(0)
      @source_paths     = []
      @source           = ""
      require(pathname)
    end

    def requirable?(pathname)
      content_type == pathname.content_type
    end

    def require(pathname)
      if requirable?(pathname)
        unless source_paths.include?(pathname.path)
          source_paths << pathname.path
          source << process(pathname)
        end
      else
        raise ContentTypeMismatch, "#{pathname.path} is " +
          "'#{pathname.format_extension}', not '#{format_extension}'"
      end
    end

    def each
      yield source
    end

    def length
      source.length
    end

    def digest
      Digest::MD5.hexdigest(source)
    end

    def stale?
      mtime < @source_paths.map { |p| File.mtime(p) }.max
    end

    protected
      def process(pathname)
        result = process_source(pathname)
        pathname.engine_extensions.reverse_each do |extension|
          result = Tilt[extension].new { result }.render
        end
        result
      end

      def process_source(pathname)
        source_file = SourceFile.new(pathname)
        processor   = Processor.new(environment, source_file)
        result      = ""

        if source_file.mtime > mtime
          @mtime = source_file.mtime
        end

        processor.required_pathnames.each { |pathname| require(pathname) }
        result << source_file.header
        processor.included_pathnames.each { |pathname| result << process(pathname) }
        result << source_file.body

        result
      end
  end
end