require 'ostruct'
require 'net/ldap'

module LDAP
  module API

    # def list_fields
    #   puts "---------- LDAP::API list_fields ------------"
    #   puts "Config.ldap_fields.inspect : #{Config.ldap_fields.inspect}"
    #   puts "--------------------------------------"
    # end

    def fetch_ldap_rec(id)
      ldap_rec = OpenStruct.new

      filter = Net::LDAP::Filter.eq('uid', id)

      ldap = Net::LDAP.new :host => host,
        :port => 389,
        :auth => {
          :method => :simple,
          :username => 'uid=library-hrms-epl,ou=applications,dc=berkeley,dc=edu',
          :password => pass
        }
      
        # Extract required fields and bundle into open struct
        if ldap.bind
          ldap.search(:base => base, :filter => filter) do |entry|
            entry.each do |attribute, values|
              ldap_rec[attribute] = values
              # values.each do |value|
              # end
            end
          end
        end
        
        return ldap_rec
    end
    
    private

    def host
      Config.secrets.ldap.host
    end

    # def bind
    #   'uid=library-hrms-epl,ou=applications,dc=berkeley,dc=edu'
    # end

    def base
      'ou=people,dc=berkeley,dc=edu'
    end

    def pass
      Config.secrets.ldap.pass
    end

  end
end
