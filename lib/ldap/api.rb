# frozen_string_literal: true

require 'net/ldap'

module LDAP
  # Fetches an LDAP record by UID returns an struct
  module API
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def fetch_ldap_rec(id)
      ldap_rec = ldap_struct_class.new

      filter = Net::LDAP::Filter.eq('uid', id)

      # Track number of attempts incase of a timeout or other temporary glitch
      attempts = 0

      # Extract required fields and bundle into open struct
      begin
        ldap = ldap_connection
        attempts += 1
        sleep(5) if attempts > 1

        ldap.bind
        ldap.search(base: base, filter: filter) do |entry|
          entry.each do |attribute, values|

            # Only grab the LDAP fields we care about....
            attr_sym = attribute.to_sym
            next unless ldap_rec.members.include?(attr_sym)

            ldap_rec[attr_sym] = values
          end
        end
      rescue StandardError => e
        attempts += 1
        logger.error "  LDAP Error: #{e}"
        retry if attempts <= 3
        return nil
      end
      logger.info '  LDAP Error: Recovered from LDAP Error!' if attempts > 1
      ldap_rec
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    private

    def ldap_connection
      Net::LDAP.new host: host,
                    port: 636,
                    encryption: {
                      method: :simple_tls
                    },
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

    # Define the LDAP Struct from the attributes we have in config > ldap_fields.yml[attributes]
    def ldap_struct_class
      return self.class::Ldap if self.class.const_defined?(:Ldap, false)

      attribute_symbols = Config.ldap_attributes.map(&:to_sym)
      self.class.const_set(:Ldap, Struct.new(*attribute_symbols, keyword_init: true))
    end
  end
end
