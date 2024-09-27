require 'nokogiri'
require_relative 'xml_builder'

module Alma
  class XMLWriter
    attr_reader :out

    def initialize(outfile)
      @out = ensure_io(outfile)
    end

    def write(record)
      ensure_open!
      record_element = XMLBuilder.new(record).build
      record_element.write_to(out)
      out.write("\n")
    end

    def close
      out.write('</users>') if @open
      out.close
    end

    class << self
      def open(out)
        writer = new(out)
        writer.send(:ensure_open!)
        yield writer if block_given?
        writer.close
      end
    end

    private

    def ensure_open!
      return if @open

      out.write(prolog_and_opening_tag)
      @open = true
    end

    def prolog_and_opening_tag
      tag = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
      tag += "<!-- GIT_COMMIT:#{ENV['GIT_COMMIT']} -->\n"
      tag += "<!-- DOCKER_TAG:#{ENV['DOCKER_TAG']} -->\n"
      tag += "<!-- VERSION: 1.5.4 -->\n"
      tag += "<users>\n"
      tag
    end

    def ensure_io(file)
      return file if writer_like?(file)
      return File.open(file, 'wb') if parent_exists?(file)

      raise ArgumentError, "Don't know how to write XML to #{file.inspect}: not an IO or file path"
    end

    # TODO: move these to a separate module...
    def writer_like?(obj)
      obj.respond_to?(:write) && obj.respond_to?(:close)
    end

    def parent_exists?(path)
      (path.respond_to?(:parent) && path.parent.exist?) ||
        (path.respond_to?(:to_str) && Pathname.new(path).parent.exist?)
    end
  end
end
