require 'nokogiri'

module Alma
  class XMLBuilder
    attr_accessor :doc

    def initialize(recs)
      @doc = build(recs)
    end

    def build(recs)
      return Nokogiri::XML::Builder.new do |xml|
        xml.users {
          
          # GENERATE USER ELEMENTS
          recs.each_with_index do |rec, idx|
            r = rec.rec

            xml.user {
              
              xml.record_type   'PUBLIC'
              xml.primary_id    r.primary_id
              xml.first_name    r.first_name
              xml.middle_name   r.middle_name if r.middle_name
              xml.last_name     r.last_name
              xml.full_name
              xml.user_group    r.user_group
              xml.campus_code   'UCB Campus'
              xml.expiry_date   r.expiry_date
              xml.purge_date    r.purge_date
              xml.account_type  'EXTERNAL'
              xml.status        'ACTIVE'

              # CONTACT INFO CONTAINS ADDRESSES, EMAILS, PHONES
              if r.contact_info

                xml.contact_info {
                  
                    if r.contact_info.addresses
                      address = r.contact_info.addresses

                      # BUILD CONTACT>ADDRESSES
                      xml.addresses {
                        xml.address(:preferred => "#{address.preferred}", :segment_type => "Internal") {
                          xml.line1           address.line1
                          xml.line2           address.line2
                          xml.city            address.city
                          xml.state_province  address.state_province
                          xml.postal_code     address.postal_code
                          xml.country         address.country
                          xml.address_note    address.address_note
                          xml.start_date      address.start_date
                          xml.end_date        address.end_date
                          xml.address_types {
                            xml.address_type  address.address_types
                          }
                        }
                      }

                    end
                  
                    # BUILD CONTACT>EMAILS
                    if r.contact_info.emails
                      email = r.contact_info.emails

                      xml.emails {
                        xml.email(:preferred => "#{email.preferred}", :segment_type => "Internal") {
                          xml.email_address email.email_address
                          xml.email_types {
                            xml.email_type  email.email_types
                          }
                        }
                      }
                    else
                      xml.emails
                    end

                    # BUILD CONTACT>PHONES
                    # TODO - see if this is correct...or if I shouldn't have block if no phone found!
                    if r.contact_info.phones
                      phone = r.contact_info.phones

                      xml.phones {
                        xml.phone(:preferred => "#{phone.preferred}", :segment_type => "External") {
                          xml.phone_number  phone.phone_number
                          xml.phone_types {
                            xml.phone_type  phone.phone_types
                          }
                        }
                      }
                    else
                      xml.phones
                    end
                }
              end

              # BUILD USER_IDENTIFIERS FROM ARRAY OF IDENTIFIERS
              if r.identifiers
                xml.user_identifiers {
                  r.identifiers.each do |identifier|
                    xml.user_identifier(:segment_type => "#{identifier.segment_type}") {
                      xml.id_type   identifier.id_type
                      xml.value     identifier.value
                      xml.status    identifier.status
                    }
                  end
                }
              end
            }
          end
        }
      end
    end
  end
end
