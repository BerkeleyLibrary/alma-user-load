require 'net/ldap'

module LDAP
  module API

    # TODO - delete after dev complete
    def list_fields
      puts "---------->Heyy!"
      # Config.ucpath_employee_fields.each do |f|

      puts "---------- API | line# 8 ------------"
      puts "Config.ldap_fields.inspect : #{Config.ldap_fields.inspect}"
      puts "--------------------------------------"
    end

    def fetch_ldap_rec(id)

      puts "----->Fetching LDAP ID: #{id}"
      filter = Net::LDAP::Filter.eq('uid', id)

      ldap = Net::LDAP.new :host => host,
        :port => 389,
        :auth => {
          :method => :simple,
          :username => 'uid=library-hrms-epl,ou=applications,dc=berkeley,dc=edu',
          :password => pass
        }
      
        # TODO - extract required fields and bundle into object!
        if ldap.bind
          ldap.search(:base => base, :filter => filter) do |entry|
            puts "---------->DN: #{entry.dn}"
            entry.each do |attribute, values|
              puts "--------------->#{attribute}"
              values.each do |value|
                puts "-------------------->#{value}"
              end
            end
          end
      
        else
          # TODO - Handle error!
          puts "----->fuccck..."
        end
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
