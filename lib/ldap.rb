require_relative 'ldap/api'

module LDAP
  VERSION = '1.0'
  include LDAP::API
end
