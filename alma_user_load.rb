# !/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

# Load library
require_relative 'config/config'
require_relative 'lib/helpers'
require_relative 'lib/docker'
require_relative 'lib/alma'
require_relative 'lib/ldap'
require_relative 'lib/sis'
require_relative 'lib/ucpath'
require_relative 'lib/logging'

# Include modules
# rubocop:disable Style/MixinUsage
# Look into moving these includes to classes...
include SIS
include Alma
include LDAP
include UCPath
include Helpers
include Logging
# rubocop:enable Style/MixinUsage

setup = Helpers::Setup.new

logger.info "Type: #{setup.type}"

case setup.type
when 'ucpath'
  UCPath.run_ucpath setup
when 'sis'
  SIS.run_sis setup
else
  puts Config.help
end
