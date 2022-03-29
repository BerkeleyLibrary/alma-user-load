# frozen_string_literal: true

require 'logger'

# TODO: - understand how this works!!!
# Found and cribbed from:
# https://stackoverflow.com/questions/917566/ruby-share-logger-instance-among-module-classes

# Logging exporter
module Logging
  class << self
    def logger
      @logger ||= Logger.new($stdout)
    end
  end

  def self.included(base)
    class << base
      def logger
        Logging.logger
      end
    end
  end

  def logger
    Logging.logger
  end
end
