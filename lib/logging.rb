# frozen_string_literal: true

require 'logger'

# Don't buffer stdout or stderr
$stdout.sync = true
$stderr.sync = true

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
