# frozen_string_literal: true

require 'ostruct'
require 'net/ldap'

module LDAP
  # Fetches an LDAP record by UID returns an ostruct
  module API
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def fetch_ldap_rec(id)
      logger.info '  starting LDAP fetch'
      ldap_rec = OpenStruct.new
      filter = Net::LDAP::Filter.eq('uid', id)

      # Track number of attempts incase of a timeout or other temporary glitch
      attempts = 0

      # Extract required fields and bundle into open struct
      begin
        ldap = ldap_connection
        attempts += 1
        sleep(5) if attempts > 1
        logger.info "  Attempt: #{attempts}" if attempts > 1

        ldap.bind
        ldap.search(base: base, filter: filter) do |entry|
          entry.each do |attribute, values|
            ldap_rec[attribute] = values
          end
        end
      rescue StandardError => e
        attempts += 1
        logger.error "  LDAP Error: #{e}"
        retry if attempts <= 3
        return nil
      end
      logger.info '  LDAP Error: Recovered from LDAP Error!' if attempts > 1
      logger.info '  finished LDAP fetch'
      ldap_rec
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    private

    # rubocop:disable Metrics/MethodLength
    def ldap_connection
      Net::LDAP.new host: host,
                    port: 636,
                    encryption: {
                      method: :simple_tls,
                      tls_options: OpenSSL::SSL::SSLContext::DEFAULT_PARAMS
                    },
                    auth: {
                      method: :simple,
                      username: 'uid=library-hrms-epl,ou=applications,dc=berkeley,dc=edu',
                      password: pass
                    }
    end
    # rubocop:enable Metrics/MethodLength

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
