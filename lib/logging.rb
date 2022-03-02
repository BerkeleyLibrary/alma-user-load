# frozen_string_literal: true

require 'logger'

# TODO: - understand how this works!!!
# Found and cribbed from:
# https://stackoverflow.com/questions/917566/ruby-share-logger-instance-among-module-classes

module Logging
  class << self
    def logger
      # @logger ||= Logger.new($stdout)
      # TODO - put filename/daily in config
      @logger ||= Logger.new('log/log.txt', 'daily')
    end

    # Example cribbed from stackoverflow referenced above had the following
    # 3 lines of code. RSPEC says that they're not being hit... so wondering
    # if they're not needed... Commenting out for now but leaving here until
    # I'm sure they're not needed.
    # def logger=(logger)
    #   @logger = logger
    # end
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
