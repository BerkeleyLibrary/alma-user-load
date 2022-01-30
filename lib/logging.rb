require 'logger'

# TODO - understand how this works!!!
# Found and cribbed from:
# https://stackoverflow.com/questions/917566/ruby-share-logger-instance-among-module-classes

module Logging
  class << self
    def logger
      # @logger ||= Logger.new($stdout)
      # TODO - put filename/daily in config
      @logger ||= Logger.new('log/log.txt', 'daily')
    end

    def logger=(logger)
      @logger = logger
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
