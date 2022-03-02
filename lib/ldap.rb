# frozen_string_literal: true

require_relative 'ldap/api'

# LDAP exporter
module LDAP
  VERSION = '1.0'
  include LDAP::API
end
