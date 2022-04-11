# frozen_string_literal: true

require_relative 'alma/xml_builder'
require_relative 'alma/xml_writer'

module Alma
  VERSION = '1.0'
  ROOT = File.dirname __dir__

  # Because api.rb is a module you need to include it...
  # include Alma::API
end
