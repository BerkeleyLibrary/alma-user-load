require 'nokogiri'

module Alma
  class XMLBuilder
    attr_accessor :user

    def initialize(user)
      @user = user
    end

    def build
      builder.doc.root.tap(&:unlink)
    end

    private

    # rubocop :disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def builder
      # Extract the user's record form the user object:
      r = user.rec

      # rubocop :disable Metrics/BlockLength
      Nokogiri::XML::Builder.new do |xml|
        xml.user do
          xml.record_type     'PUBLIC'
          xml.primary_id      r.primary_id
          xml.first_name      r.first_name
          xml.middle_name     r.middle_name if r.middle_name
          xml.last_name       r.last_name
          xml.full_name       r.full_name
          xml.job_description r.job_description
          xml.user_group      r.user_group
          xml.campus_code     'UCB_Campus'
          xml.expiry_date     r.expiry_date
          xml.purge_date      r.purge_date
          xml.account_type    'EXTERNAL'
          xml.status          'ACTIVE'

          # CONTACT INFO CONTAINS ADDRESSES, EMAILS, PHONES
          if r.contact_info
            xml.contact_info do
              if r.contact_info.addresses
                addresses = r.contact_info.addresses

                addresses = [addresses] unless addresses.is_a?(Array)

                # BUILD CONTACT>ADDRESSES
                xml.addresses do
                  addresses.each do |address|
                    xml.address(preferred: address.preferred.to_s, segment_type: 'Internal') do
                      xml.line1           address.line1
                      xml.line2           address.line2
                      xml.city            address.city
                      xml.state_province  address.state_province
                      xml.postal_code     address.postal_code
                      xml.country         address.country
                      xml.address_note    address.address_note
                      xml.start_date      address.start_date
                      xml.end_date        address.end_date
                      xml.address_types do
                        xml.address_type address.address_types
                      end
                    end
                  end
                end
              end

              # BUILD CONTACT>EMAILS
              if r.contact_info.emails.email_address && r.contact_info.emails.email_address != ''
                email = r.contact_info.emails

                xml.emails do
                  xml.email(preferred: email.preferred.to_s, segment_type: 'Internal') do
                    xml.email_address email.email_address
                    xml.email_types do
                      xml.email_type  email.email_types
                    end
                  end
                end
              else
                xml.emails
              end

              # BUILD CONTACT>PHONES
              if r.contact_info.phones
                phone = r.contact_info.phones

                xml.phones do
                  xml.phone(preferred: phone.preferred.to_s, preferred_sms: phone.preferred_sms.to_s,
                            segment_type: 'External') do
                    xml.phone_number phone.phone_number
                    xml.phone_types do
                      xml.phone_type  phone.phone_types
                    end
                  end
                end
              else
                xml.phones
              end
            end
          end

          # BUILD USER_IDENTIFIERS FROM ARRAY OF IDENTIFIERS
          if r.identifiers
            xml.user_identifiers do
              r.identifiers.each do |identifier|
                xml.user_identifier(segment_type: identifier.segment_type.to_s) do
                  xml.id_type   identifier.id_type
                  xml.value     identifier.value
                  xml.status    identifier.status
                end
              end
            end
          end

          # USER_STATISTICS - COMING SOON!
          # if r.statistics
          #   xml.user_statistics {
          #     r.statistics.each do |stat|
          #       # <user_statistic segment_type="External">
          #       #   <statistic_category>UCB</statistic_category>
          #       #   <category_type></category_type>
          #       #   <statistic_note>FYUHS</statistic_note>
          #       # </user_statistic>
          #     end
          #   }
          # end

          # AP-0182 : Use preferred names above and don't populate here
          # if r.preferred_name
          #   xml.pref_first_name   r.pref_name_givenname
          #   xml.pref_middle_name  r.pref_name_middlename
          #   xml.pref_last_name    r.pref_name_familyname
          #   xml.pref_full_name    r.pref_name_fullname
          # end
        end
      end
      # rubocop :enable Metrics/BlockLength
    end
    # rubocop :enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  end
end
