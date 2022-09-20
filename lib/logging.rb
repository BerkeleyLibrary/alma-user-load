# frozen_string_literal: true

require 'logger'

# Don't buffer stdout or stderr
$stdout.sync = true
$stderr.sync = true

# Logging exporter
module Logging
  @errors = []
  def self.error(err)
    @errors.push(err)
  end

  def self.errors?
    !@errors.empty?
  end

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
