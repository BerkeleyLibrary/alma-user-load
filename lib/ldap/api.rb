# frozen_string_literal: true

require 'ostruct'
require 'net/ldap'

module LDAP
  # Fetches an LDAP record by UID returns an ostruct
  module API
    # rubocop:disable Metrics/MethodLength
    def fetch_ldap_rec(id)
      ldap_rec = OpenStruct.new
      filter = Net::LDAP::Filter.eq('uid', id)
      ldap = ldap_connection

      # Extract required fields and bundle into open struct
      if ldap.bind
        ldap.search(base: base, filter: filter) do |entry|
          entry.each do |attribute, values|
            ldap_rec[attribute] = values
          end
        end
      end

      ldap_rec
    end
    # rubocop:enable Metrics/MethodLength

    private

    def ldap_connection
      Net::LDAP.new host: host,
                    port: 389,
                    auth: {
                      method: :simple,
                      username: 'uid=library-hrms-epl,ou=applications,dc=berkeley,dc=edu',
                      password: pass
                    }
    end

    def host
      Config.secrets.ldap.host
    end

    def base
      'ou=people,dc=berkeley,dc=edu'
    end

    def pass
      Config.secrets.ldap.pass
    end
  end
end
