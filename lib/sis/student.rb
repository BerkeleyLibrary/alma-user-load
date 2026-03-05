# frozen_string_literal: true

require 'json'
require 'date'

# rubocop:disable Metrics/ClassLength
module SIS
  # Student object for processing into Alma XML file
  class Student
    attr_accessor :rec, :user

    Statistic = Struct.new(:segment_type, :category, :type, :note)
    Identifier = Struct.new(:segment_type, :id_type, :value, :status)
    ContactInfo = Struct.new(:addresses, :emails, :phones)
    Address = Struct.new(:preferred, :line1, :line2, :city, :state_province, :postal_code, :country, :address_note,
                         :start_date, :end_date, :address_types)
    Email = Struct.new(:preferred, :email_address, :email_types)
    Phone = Struct.new(:preferred, :preferred_sms, :phone_number, :phone_types)

    Rec = Struct.new(:primary_id, :job_description, :expiry_date, :purge_date, :contact_info,
                     :identifiers, :user_group, :full_name, :first_name, :middle_name, :last_name,
                     :preferred_name, :pref_name_givenname, :pref_name_middlename, :pref_name_familyname,
                     :campus_code, :account_type, :status,
                     keyword_init: true)

    def initialize(user)
      @user = user
      @rec = Rec.new
      create_user_record
    end

    private

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def create_user_record
      rec.primary_id = user['student_id']

      # NAMES
      set_primary_name
      set_preferred_name

      # JOB_DESCRIPTION (Student's Major - comes from academic plan desc)
      rec.job_description = user['acadplan_descr'] || nil

      # USER_GROUP
      set_user_group

      # EXPIRY_DATE
      withcncl = user['withcncl'] || ''
      rec.expiry_date = Helpers::ApplicationHelper.sis_expire_date(withcncl)

      # PURGE_DATE (expiry date plus one year)
      rec.purge_date = Date.iso8601(rec.expiry_date).next_year.to_s

      # CONTACT_INFO
      rec.contact_info = create_contact_info

      # USER_IDENTIFIERS
      rec.identifiers = create_identifiers

      # MISC. HARDCODED VALUES
      set_static_values
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    def set_user_group
      rec.user_group = case user['acadcareer_code']
                       when 'GRAD', 'LAW'
                         'GRADSTUD'
                       when 'UCBX'
                         'UCEXTSTUD'
                       when 'UGRD'
                         'UNDERGRAD'
                       else
                         logger.warn "Unrecognized Career Code: #{user['acadcareer_code']}"
                         user['acadcareer_code']
                       end
    end
    # rubocop:enable Metrics/MethodLength

    def set_primary_name
      rec.first_name = user['prim_name_givenname']
      rec.middle_name = user['prim_name_middlename'] || nil
      rec.last_name = user['prim_name_familyname']
    end

    def set_preferred_name
      rec.preferred_name = true
      rec.pref_name_givenname = user['pref_name_givenname'] || nil
      rec.pref_name_middlename = user['pref_name_middlename'] || nil
      rec.pref_name_familyname = user['pref_name_familyname'] || nil
    end

    def create_contact_info
      c = ContactInfo.new
      c.addresses = create_addresses
      c.emails = create_email
      c.phones = create_phone unless user['phone_number'].nil? || user['phone_number'].empty?
      c
    end

    def create_addresses
      addresses = []
      addresses.push(parse_local_address) if user['locl_address_address1'] && user['locl_address_address1'] != ''
      addresses.push(parse_home_address) if user['home_address_address1'] && user['home_address_address1'] != ''
      addresses
    end

    # rubocop:disable Metrics/AbcSize
    def parse_local_address
      a = Address.new
      a.preferred = 'true'
      a.line1 = user['locl_address_address1'] || ''
      a.line2 = user['locl_address_address2'] || ''
      a.city = user['locl_address_city'] || ''
      a.state_province = user['locl_address_statecode'] || ''
      a.postal_code = user['locl_address_postalcode'] || ''
      a.address_types = 'school'
      a
    end

    def parse_home_address
      a = Address.new
      a.preferred = 'false'
      a.line1 = user['home_address_address1'] || ''
      a.line2 = user['home_address_address2'] || ''
      a.city = user['home_address_city'] || ''
      a.state_province = user['home_address_statecode'] || ''
      a.postal_code = user['home_address_postalcode'] || ''
      a.address_types = 'home'
      a
    end
    # rubocop:enable Metrics/AbcSize

    def create_email
      e = Email.new
      e.preferred = 'true'
      e.email_address = user['email_emailaddress']
      e.email_types = 'school'
      e
    end

    def create_phone
      telephone = format_phone user['phone_number']
      p = Phone.new
      p.preferred = 'false'
      p.preferred_sms = 'false'
      p.phone_number = telephone || nil
      p.phone_types = 'home'
      p
    end

    # TODO: DRY this up! This is also in ucpath::user
    #----------------------------------------------------------------#
    # Regular Expression Jujitsu:                                    #
    # Apparently Alvin's run into some severely mutilated phone      #
    # numbers - the Following series of REGEXs were cribbed and      #
    # translated from 20111130_Current_Procedures document on bdrive #
    #----------------------------------------------------------------#
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

    def format_phone(telephone)
      preserved_number = telephone
      telephone = telephone.sub(/^\+1\s+/, '')
      telephone = telephone.sub(/^1-/, '')
      telephone = telephone.sub(/^1\s+/, '')
      telephone = telephone.sub(/\s+\([^()]+\)$/, '')
      telephone = telephone.gsub('.', '-')
      telephone = telephone.sub(/-x\d+$/, '')
      telephone = telephone.gsub('/', '-')
      telephone = telephone.gsub('(', '')
      telephone = telephone.gsub(')', '')
      telephone = telephone.sub(/^\s+/, '')
      telephone = telephone.sub(/\s+$/, '')

      # rubocop:disable Lint/DuplicateBranch
      case telephone
      when /^\d{3}-\d{3}-\d{4}$/
        # Correct format, hooray!
      when /^(\d{3})[- ](\d{3})-(\d{4})$/
        # A little wishy washy:  111 222-3333
        telephone = "#{Regexp.last_match(1)}-#{Regexp.last_match(2)}-#{Regexp.last_match(3)}"
      when /^(\d{3})(\d{3})(\d{4})$/
        # Okay I guess:  1112223333
        telephone = "#{Regexp.last_match(1)}-#{Regexp.last_match(2)}-#{Regexp.last_match(3)}"
      when /^(\d{3})[ -]?(\d{4})$/
        # Lazy...no area code:  111-2222
        telephone = "510-#{Regexp.last_match(1)}-#{Regexp.last_match(2)}"
      when /^(\d)[ -]?(\d{4})$/
        # WTF!?!  1 2222
        telephone = "510-64#{Regexp.last_match(1)}-#{Regexp.last_match(2)}"
      else
        # Apparently we have not... Log it
        # logger.info "#{id} - Failed to process phone number: #{preserved_number}"
        # puts "Failed Phone number: #{preserved_number}"
        return preserved_number
      end
      # rubocop:enable Lint/DuplicateBranch

      telephone
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def set_static_values
      rec.campus_code = 'UCB_Campus'

      # ACCOUNT_TYPE
      rec.account_type = 'EXTERNAL'

      # STATUS - SAFE TO ASSUME ACTIVE???
      rec.status = 'ACTIVE'
    end

    # rubocop:disable Metrics/AbcSize
    def create_identifiers
      identifiers = []

      # student-id
      #  - Only want this ID if it's "newer" (begins with '30')
      #  - Only want the last 8 digits for this barcode
      identifiers.push(create_identifier(user['student_id'].chars.last(8).join)) if user['student_id'] && user['student_id'][/^30.*/]

      # campus-uid
      identifiers.push(create_univ_id(user['campus_uid'])) if user['campus_uid']

      identifiers
    end
    # rubocop:enable Metrics/AbcSize

    def create_identifier(identifier, prefix = nil)
      i = Identifier.new
      i.segment_type = 'Internal'
      i.id_type = 'BARCODE'
      i.value = "#{prefix || ''}#{identifier}"
      i.status = 'ACTIVE'

      i
    end

    def create_univ_id(identifier, prefix = nil)
      i = Identifier.new
      i.segment_type = 'Internal'
      i.id_type = 'UNIV_ID'
      i.value = "#{prefix || ''}#{identifier}"
      i.status = 'ACTIVE'

      i
    end

  end
end
# rubocop:enable Metrics/ClassLength
