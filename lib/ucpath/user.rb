# frozen_string_literal: false

require 'date'
require 'json'
require 'ostruct'

# I don't think I need these:
require 'jsonpath'
require 'nokogiri'
require_relative 'user'
require_relative '../alma'

# TODO: - Decomposition
# Break this into a bunch of smaller objects
# raw_ucpath
# ldap
# user_record
# statistics
# user_group
# identifiers
# contact_info
#  -> emails
#  -> phones
#  -> addresses

module UCPath
  # UCPath::User
  # TODO: break this down into much a smaller number of classes.
  # rubocop:disable Metrics/ClassLength
  class User
    attr_accessor :id, :rec, :user, :jobs, :errors, :ldap, :eligible, :ucpath_rec

    Statistic = Struct.new(:segment_type, :category, :type, :note)
    Identifier = Struct.new(:segment_type, :id_type, :value, :status)
    ContactInfo = Struct.new(:addresses, :emails, :phones)
    Address = Struct.new(:preferred, :line1, :line2, :city, :state_province, :postal_code, :country, :address_note,
                         :start_date, :end_date, :address_types)
    Email = Struct.new(:preferred, :email_address, :email_types)
    Phone = Struct.new(:preferred, :preferred_sms, :phone_number, :phone_types)

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def initialize(id)
      @id = id
      logger.info "#{id} - Begin processing record"

      @errors = []

      # We'll assume this user is ineligible until we know otherwise
      @eligible = false

      #----------------------------------------------------------------#
      # THESE RECORDS ARE A BIT MORE FLEXIBLE AND THUS USING OPENSTRUCTS
      @rec = OpenStruct.new
      @ucpath_rec = OpenStruct.new

      #----------------------------------------------------------------#
      # FETCH & PARSE UCPATH DATA
      logger.info "#{id} - Fetching ucpath record"
      @user = fetch_user
      if @user.nil?
        @errors.push('Failed to fetch UCPath record')
        return
      end

      parse_user

      logger.info "#{id} - Fetching ucpath jobs data"
      @jobs = fetch_jobs
      return if @jobs.nil?

      parse_jobs

      #----------------------------------------------------------------#
      # FETCH LDAP
      # TODO - only hit LDAP if you have a valid job!
      logger.info "#{id} - Fetching LDAP record: #{@ucpath_rec.uid}"
      @ldap = LDAP::API.fetch_ldap_rec(@ucpath_rec.uid)

      #----------------------------------------------------------------#
      # FETCH ALMA RECORD (NOT SURE IF I'LL NEED THIS OR NOT....)
      # @alma_rec = Alma::User.new
      # @alma_rec.load_user(id)
      # puts "Last Name: #{@alma_rec.user.last_name}"

      #----------------------------------------------------------------#
      # CREATE THE USER RECORD (@rec) FROM THE ABOVE DATA SOURCES
      logger.info "#{id} - Creating user record"
      create_user_record

      logger.info "#{id} - Eligible: #{eligible?}"
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def eligible?
      eligible
    end

    #----------------------------------------------------------------#
    # CREATE A FINAL RECORD THAT CAN BE USED FOR GENERATING XML
    # TODO - probably want to move this into a separate class
    #        "AlmaUser" or something like that, then I can reuse
    #        most of the code when I setup SIS.
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def create_user_record
      rec.primary_id = ucpath_rec.ucpath_employee_id

      #----------------------------------------------------------------#
      # STUDENT CHECK - berkeleyeduaffiliations in Student Affiliation (ldap_fields.yml)
      if ldap&.berkeleyeduaffiliations
        ldap.berkeleyeduaffiliations.each do |affiliation|
          if Config.student_affiated? affiliation
            logger.info "#{id} - Ineligible - ldap student affiliation: #{affiliation}"
            return nil
          end
        end
      end

      #----------------------------------------------------------------#
      # NAMES:
      # Get first_name, middle_name, last_name from the primary UCPath Employee record
      # If the UCPath lacks first_name and last_name, use LDAP record
      if ucpath_rec.first_name != '' && ucpath_rec.last_name != ''
        rec.first_name = ucpath_rec.first_name
        rec.last_name = ucpath_rec.last_name
        rec.middle_name = ucpath_rec.middle_name if ucpath_rec.middle_name
      else
        rec.first_name = ldap.givenname.first
        rec.last_name = ldap.sn.first
      end

      # Set the Full Name:
      rec.full_name = rec.first_name
      rec.full_name += " #{rec.middle_name}" if rec.middle_name
      rec.full_name += " #{rec.last_name}"

      # preferred names: (if present in UCPath)
      rec.pref_name_givenname = ucpath_rec.pref_name_givenname unless ucpath_rec.pref_name_givenname.empty?
      rec.pref_name_familyname = ucpath_rec.pref_name_familyname unless ucpath_rec.pref_name_familyname.empty?
      rec.pref_name_middlename = ucpath_rec.pref_name_middlename unless ucpath_rec.pref_name_middlename.empty?

      # Set the Full Name:
      # TODO: move this into a library
      if rec.pref_name_givenname && rec.pref_name_familyname
        rec.preferred_name = true
        rec.pref_name_fullname = rec.pref_name_givenname
        rec.pref_name_fullname += " #{rec.pref_name_middlename}" unless rec.pref_name_middlename.nil?
        rec.pref_name_fullname += " #{rec.pref_name_familyname}"
      end

      #----------------------------------------------------------------#
      # USER_GROUP:
      # Probably spin this off to a separate function!
      rec.user_group = nil

      ineligible_reasons = []

      # rubocop:disable Metrics/BlockLength
      ucpath_rec.jobs.each do |j|
        # Assume this job is eligible - this is based on the 3 criteria below
        job_eligible = true

        # 1. hrStatus/code = A
        unless j.hr_status_code == 'A'
          ineligible_reasons.push("#{rec.primary_id} - Ineligible: HR status code: '#{j.hr_status_code}' - must be 'A'")
          job_eligible = false
        end

        # 2. If their Job record has an expectedEndDate, it must be on or after today's date.
        # unless j.expected_end_date.blank?
        unless !j.expected_end_date || j.expected_end_date == ''
          ineligible_reasons.push("#{rec.primary_id} - Ineligible: expected_end_date not in the future")
          job_eligible = false if Date.iso8601(j.expected_end_date) <= Date.today
        end

        # 3. If their organizationRelationship/code = 'CWR' their jobCode must be within
        #    the Visiting Scholar category.
        # unless j.org_relationship_code.blank?
        if !(!j.org_relationship_code || j.org_relationship_code == '') && (j.org_relationship_code == 'CWR')
          ineligible_reasons.push("#{rec.primary_id} - Ineligible: org code CWR has non visiting scholar job code")
          job_eligible = false unless Config.check_ucpath_code('Visiting Scholar Job Code', j.job_code)
        end

        next unless job_eligible

        # Found eligible job - clear out any previous ineligible reasons
        ineligible_reasons = nil

        # JOB DESCRIPTION
        rec.job_description = j.dept_desc || nil

        # USER_GROUP
        rec.user_group = if Config.check_ucpath_code('Library Staff Dept Code Prefix', j.dept_code) ||
                            Config.check_ucpath_code('Library Staff Job Code', j.job_code)
                           'LIBSTAFF'
                         elsif Config.check_ucpath_code('Postdoc Job Code', j.job_code)
                           'UCB POST'
                         elsif Config.check_ucpath_code('Visiting Scholar Job Code', j.job_code)
                           'UCBVISSCHOL'
                         elsif Config.check_ucpath_code('Academic Classification Indic', j.classification_indc) &&
                               Config.check_ucpath_code('UC Extension Faculty', j.dept_code)
                           'UCEXT'
                         elsif Config.check_ucpath_code('Academic Classification Indic', j.classification_indc) ||
                               Config.check_ucpath_code('Emeritus Job Code', j.job_code)
                           'FACULTY'
                         elsif Config.check_ucpath_code('Executive Classification Indic', j.classification_indc)
                           'EXECUTIVE'
                         else
                           'NONACAD'
                         end

        # EXPIRY_DATE
        # if j.expected_end_date.blank?
        rec.expiry_date = if !j.expected_end_date || j.expected_end_date == ''
                            create_expected_end_date
                          else
                            j.expected_end_date
                          end

        # PURGE_DATE (expiry date plus one year)
        rec.purge_date = Date.iso8601(rec.expiry_date).next_year.to_s

        # Oddly, addresses, emails and phones are taken from this one and only job...weird!
        rec.contact_info = create_contact_info(j)

        # CAMPUS_CODE
        rec.campus_code = 'UCB_Campus'

        # ACCOUNT_TYPE
        rec.account_type = 'EXTERNAL'

        # STATUS - SAFE TO ASSUME ACTIVE???
        # rec.status = 'ACTIVE' if j.job_status_code == 'A'
        rec.status = 'ACTIVE'

        # USER_IDENTIFIERS
        rec.identifiers = create_identifiers

        # USER_ROLES - DROP (according to D.Rez, Alma should assign)
        # USER_STATISTICS - TBD (addording to J.Gosselar these have yet to be determined)

        # SET USER ELIGIBILITY
        self.eligible = job_eligible

        # We've found an job_eligible job... we set the user group, no need to go through more jobs
        break
      end
      # rubocop:enable Metrics/BlockLength

      ineligible_reasons&.each do |r|
        logger.info r
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

    # rubocop:disable Metrics/AbcSize
    def create_identifiers
      identifiers = []

      # hr-employee-id : Note add 'E' prefix
      identifiers.push(create_identifier(ucpath_rec.ucpath_employee_id, 'E')) if ucpath_rec.ucpath_employee_id

      # legacy-hr-employee-id
      identifiers.push(create_identifier(ucpath_rec.legacy_employee_id)) unless ucpath_rec.legacy_employee_id.empty?

      unless ucpath_rec.legacy_employee_id.empty?
        identifiers.push(create_identifier(ucpath_rec.legacy_employee_id.chars.last(7).join,
                                           'A'))
      end

      # campus-uid
      identifiers.push(create_identifier(ucpath_rec.uid)) if ucpath_rec.uid

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

    def create_contact_info(job)
      c = ContactInfo.new
      c.addresses = create_addresses job
      c.emails = create_emails
      c.phones = create_phones

      c
    end

    private

    def create_addresses(job)
      create_address(job)
    end

    def create_emails
      create_email
    end

    def create_phones
      create_phone
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def create_address(job)
      a = Address.new

      a.preferred = 'true'
      a.line1 = job.dept_desc if job.dept_desc
      a.line2 = job.location_description if job.location_description
      a.city = 'Berkeley'
      a.state_province = 'CA'
      a.postal_code = '94720'

      #----------------------------------------------------------------#
      # Dates: address_start_date/address_end_date, etc...             #
      # Per Dave Rez:                                                  #
      # I would say that setting any start date equal to the load date #
      # and the end date equal to the expiration date would be fine.   #
      # The purge date can be set for a year past the expiration date. #
      #----------------------------------------------------------------#
      a.start_date = Date.today
      a.end_date = Date.iso8601(rec.expiry_date)
      a.address_types = 'work'

      # RETURN our address struct
      a
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # TODO: - Email addresses must be checked for structural validity.

    #----------------------------------------------------------------#
    # Email                                                          #
    # Take first from the LDAP berkeleyEduOfficialEmail field,       #
    # then if not found use the primary email address from the       #
    # Employee record if it exists, otherwise use any other email    #
    # address from the record.                                       #
    #----------------------------------------------------------------#
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def create_email
      # unless !ldap.berkeleyeduofficialemail || ldap.berkeleyeduofficialemail.first.blank?
      # ldap&.berkeleyeduaffiliations
      if ldap.nil? || !ldap.berkeleyeduofficialemail || ldap.berkeleyeduofficialemail.first == ''
        # return nil if ucpath_rec.email.blank?
        return nil unless ucpath_rec.email

        e = Email.new
        e.preferred = ucpath_rec.email_primary_code
        e.email_address = ucpath_rec.email
      else
        e = Email.new
        e.preferred = 'true'
        e.email_address = ldap.berkeleyeduofficialemail.first
      end

      e.email_types = 'work'

      e
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    #----------------------------------------------------------------#
    # Phone Number                                                   #
    # Take first from the LDAP telephoneNumber field, then if not    #
    # found use the primary number from the Employee record if it    #
    # exists, otherwise use any other phone number from the record.  #
    #----------------------------------------------------------------#
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def create_phone
      if ldap.nil? || !ldap.telephonenumber || ldap.telephonenumber == ''
        return nil unless ucpath_rec.phone_number

        telephone = format_phone ucpath_rec.phone_number

        if telephone
          p = Phone.new
          p.preferred = if !ucpath_rec.phone_primary_code || ucpath_rec.phone_primary_code == ''
                          'false'
                        else
                          'true'
                        end

          p.preferred_sms = 'false'
          p.phone_number = telephone
          p.phone_types = 'office'
          return p
        end
      else
        telephone = format_phone ldap.telephonenumber.first

        if telephone
          p = Phone.new
          p.preferred = 'true'
          p.preferred_sms = 'false'
          p.phone_number = telephone
          p.phone_types = 'office'
          return p
        end
      end

      nil
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

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
        logger.info "#{id} - Failed to process phone number: #{preserved_number}"
        return nil
      end
      # rubocop:enable Lint/DuplicateBranch

      telephone
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    #----------------------------------------------------------------#
    # Per Alvin:                                                     #
    # Date advances forward expiration_year_interval years on the    #
    # first day of change_month.                                     #
    # For example on July 31 2009 the expiration date will be        #
    # 10-31-2010. On Aug 1 2009 though, the expiration date will     #
    # advance forward two years to 10-31-2011.                       #
    #----------------------------------------------------------------#
    def create_expected_end_date
      expiration_month_day = '10-31'
      expiration_year_interval = 2
      change_month = 7

      d = Date.today

      expiration_year = if d.month < change_month
                          d.year + expiration_year_interval - 1
                        else
                          d.year + expiration_year_interval
                        end

      "#{expiration_year}-#{expiration_month_day}"
    end

    # First load all UCPath Employee Data into obj
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    def parse_user
      Config.ucpath_employee_fields.each do |f|
        name = f['name']
        jpath = f['jpath']
        alt_jpath = f['alt_jpath']
        status = f['status'] || 'OPTIONAL'

        next unless jpath

        value = JsonPath.on(@user, jpath).first || ''

        # If field has an alternatate path (E.G., non primary phone)
        value = JsonPath.on(@user, alt_jpath).first || '' if value == '' && alt_jpath

        if status == 'REQUIRED' && (!value || value == '')
          errors.push("#{id} - Missing required field: #{name}")
          logger.error "#{id} - Missing required field: #{name}"
        end

        ucpath_rec[name] = value if value
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity

    # TODO: - I may need to set this up to always have the primary job
    #        as the first element in the array
    # We'll throw all the jobs into an array of open structs:
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def parse_jobs
      ucpath_rec['jobs'] = []

      # Query @jobs for the actual jobs
      job_data = JsonPath.on(@jobs, '$..response[*].jobs')

      return nil unless job_data.count.positive?

      job_data.first.each_with_index do |job, _idx|
        # JsonPath.on returns a hash - convert that back to JSON so our jsonpath path's work!
        # TODO - see if there's a better way..., this feels hacky.
        j = job.to_json

        # WORKS:
        # puts "JOBCODE  :  -->#{JsonPath.on(j.first, '$.position.jobCode.code.code')}<--"
        # Also works:
        # puts "JOBCODE  :  -->#{JsonPath.on(j, '$[*].position.jobCode.code.code')}<--"

        job = OpenStruct.new

        Config.ucpath_job_fields.each do |f|
          name = f['name']
          jpath = f['jpath']
          # status = f['status'] || 'OPTIONAL'

          next unless jpath

          value = JsonPath.on(j, jpath).first || ''

          # TODO: - verifty if there are any required job fields, I don't think there are
          # if status == 'REQUIRED' && value == ''
          #   logger.error "#{id} - Job Missing Required Field: #{name}"
          # end

          job[name] = value if value
        end

        ucpath_rec['jobs'].push(job)
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # Need to get list of users (change log or full list)
    # Need to process each user:
    #  1 - fetch the users ucpath record
    #  2 - fetch the users ucpath jobs
    #  3?? not sure after this - some data massaging I'm assuming

    #  4 - generate an XML record for the user
    #  or
    #  4 - fetch the users record from Alma
    #      compare and build xml record accordingly (add notes or other necessary fields)
    #  5 - add user xml record to the XML file
    #  6 - move XML file to processing location

    # Class function to fetch the UCPath User Change Log

    # TODO: - Remove this from here... I think at least...
    # def self.fetch_change_log(start_date, end_date)
    #   log = User.change_log(start_date, end_date) || nil
    # end

    def fetch_user
      User.fetch_ucpath_rec(id)
    end

    def fetch_jobs
      User.fetch_ucpath_jobs(id)
    end
  end
  # rubocop:enable Metrics/ClassLength
end
