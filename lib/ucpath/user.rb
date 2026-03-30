require 'date'
require 'json'
require 'jsonpath'
require 'nokogiri'
require_relative 'jobs'
require_relative '../alma'

module UCPath
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

    Rec = Struct.new(:primary_id, :first_name, :last_name, :middle_name, :full_name,
                     :user_group, :job_description, :expiry_date, :purge_date, :contact_info,
                     :campus_code, :account_type, :status, :identifiers,
                     keyword_init: true)

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def initialize(id)
      @id = id
      logger.info "#{id} - Processing record..."

      @errors = []

      # We'll assume this user is ineligible until we know otherwise
      @eligible = false

      #----------------------------------------------------------------#
      # Death to OpenStructs... long live Structs!!!
      @rec = Rec.new
      @ucpath_rec = ucpath_record_struct_class.new

      #----------------------------------------------------------------#
      # FETCH & PARSE UCPATH USER AND JOBS

      # First fetch/parse the user's ucpath record
      logger.info "#{id} - Fetching ucpath record"
      @user = fetch_user
      if @user.nil?
        @errors.push('Failed to fetch UCPath record')
        return
      end
      parse_user

      # Then get the users jobs
      # UCPath::Jobs will fetch/process users jobs
      @jobs = Jobs.new(id)

      #----------------------------------------------------------------#
      # NO ELIGIBLE JOB
      # AP-345: Changed this logic
      # If we could not find an "eligible" job we'd just skip this user
      # and move on. Now what we need to do is update the user's expiration
      # date to the current date so that they will get purged from Alma.
      # We'll either use the first job found (which is the users most recent job)
      # or we'll create a dummy job with the expected_end_date set to today.
      # AP-359: Update, do not create a dummy job if there is no job, those are
      # ineligible
      unless @jobs.eligible_job?
        if @jobs.first_job
          logger.info "#{id} - No eligible job found, using first job"
          @jobs.job = @jobs.first_job

          @jobs.job.expected_end_date = Date.today.to_s
        else
          @eligible = false
          @jobs = nil
          @user = nil
          @ucpath_rec = nil

          logger.info "#{id} - Eligible: #{eligible?}"
          return
        end
      end

      #----------------------------------------------------------------#
      # If we have a termination date that is before the last Alma
      # purge date, then we can skip this user
      term_date = @jobs.job.termination_date

      if term_date && term_date != '' && Date.iso8601(term_date) < Date.parse(Config.setting('last_alma_purge'))
        logger.info "#{id} - Ineligible: Termination date before #{Config.setting('last_alma_purge')}"
        @eligible = false
        return
      end

      #----------------------------------------------------------------#
      # FETCH LDAP
      logger.info "#{id} - Fetching LDAP record: #{@ucpath_rec.uid}"
      @ldap = LDAP::API.fetch_ldap_rec(@ucpath_rec.uid)

      #----------------------------------------------------------------#
      # CREATE THE USER RECORD (@rec) FROM THE ABOVE DATA SOURCES
      create_user_record

      #----------------------------------------------------------------#
      # Do not have email??? Then do not pass go, do not collect two hundred dollars!!!
      #
      # Note - we cannot use the "REQUIRED" status from the config fields in order to set
      #        eligibility since we can get the email address from either UCPath OR LDAP
      if eligible? && !email?
        logger.info "#{id} - Ineligible: No email address found"
        @eligible = false
      end

      #----------------------------------------------------------------#
      # CLEANUP - recover some memory
      # At this point I need @rec, @eligible, @id
      # I don't need: @jobs, @user, @ldap, @ucpath_rec
      @jobs = nil
      @user = nil
      @ldap = nil
      @ucpath_rec = nil

      logger.info "#{id} - Eligible: #{eligible?}"
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    def ucpath_record_struct_class
      return self.class::UcpathRecord if self.class.const_defined?(:UcpathRecord, false)

      keys = Config.ucpath_employee_fields.map { |f| f['name'].to_sym }
      self.class.const_set(:UcpathRecord, Struct.new(*keys, keyword_init: true))
    end

    def eligible?
      eligible
    end

    #----------------------------------------------------------------#
    # CREATE A FINAL RECORD THAT CAN BE USED FOR GENERATING XML
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def create_user_record
      rec.primary_id = ucpath_rec.ucpath_employee_id

      job_code = jobs.job.job_code || nil
      priority_job = Config.check_ucpath_code('priority_job_codes', job_code)
      percent_of_fulltime = jobs.job.percent_of_fulltime.to_f
      percent_of_fulltime_job = jobs.job.percent_of_fulltime_job.to_f

      # PERCENT OF FULL TIME CHECK
      # AP-559 If an employee is in a position that is 0 FTE,
      # their record should should be filtered out from the UCPath files.
      if !Config.skip_fte_check?(job_code) && (percent_of_fulltime.zero? && percent_of_fulltime_job.zero?)
        logger.info "#{id} - Ineligible: Percentage of Full Time Check"
        return nil
      end

      # STUDENT CHECK - berkeleyeduaffiliations in Student Affiliation (ldap_fields.yml)
      if !priority_job && ldap&.berkeleyeduaffiliations
        ldap.berkeleyeduaffiliations.each do |affiliation|
          if Config.student_affiated? affiliation
            logger.info "#{id} - Ineligible: ldap student affiliation: #{affiliation}"
            return nil
          end
        end
      end

      # EXCLUDE JOB CODE CHECK
      # AP-361: Thou Shalt not pass if the user has a Contingent Worker Job Code!
      # AP-576: Change list name and log message since this expanded beyond "contingent workers"
      if job_code && Config.check_ucpath_code('exclude_job_code', job_code)
        logger.info "#{id} - Ineligible: job code in exclude_job_code list: #{job_code}"
        return nil
      end

      # VOIDED ACCOUNT CHECK
      # AP-463: If first and last name are "VOID" skip user!
      if ucpath_rec.last_name == 'VOID' && ucpath_rec.first_name == 'VOID'
        logger.info "#{id} - Ineligible: Account is VOID"
        return nil
      end

      # NAMES
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

      # USER_GROUP - Probably spin this off to a separate function!
      rec.user_group = nil

      # Note
      # I broke most of the "Jobs" code off to UCPath::Jobs
      # rather than rename all of the references below, just
      # assign the eligible job to 'j'
      j = jobs.job

      # JOB DESCRIPTION
      rec.job_description = j.dept_desc || nil

      # USER_GROUP
      rec.user_group = if Config.check_ucpath_code('library_staff_dept_code_prefix', j.dept_code) ||
                          Config.check_ucpath_code('library_staff_job_code', j.job_code)
                         'LIBSTAFF'
                       elsif Config.check_ucpath_code('postdoc_job_code', j.job_code)
                         'UCB POST'
                       elsif Config.check_ucpath_code('visiting_scholar_job_code', j.job_code)
                         'UCBVISSCHOL'
                       elsif Config.check_ucpath_code('ucb_academic_dept_affiliate_code', j.job_code)
                         'UCBAFFILI'
                       elsif Config.check_ucpath_code('academic_classification_indic', j.classification_indc) &&
                              Config.check_ucpath_code('uc_extension_faculty', j.dept_code)
                         'UCEXT'
                       elsif Config.check_ucpath_code('academic_classification_indic', j.classification_indc) ||
                              Config.check_ucpath_code('emeritus_job_code', j.job_code)
                         'FACULTY'
                       elsif Config.check_ucpath_code('executive_classification_indic', j.classification_indc)
                         'EXECUTIVE'
                       else
                         'NONACAD'
                       end

      # EXPIRY_DATE
      rec.expiry_date = Helpers::ApplicationHelper.upcath_expire_date(rec.user_group, j.expected_end_date)

      # PURGE_DATE (expiry date plus one year)
      rec.purge_date = Date.iso8601(rec.expiry_date).next_year.to_s

      # CONTACT_INFO - build that in a separate set of functions
      # Addresses, emails and phones are taken from this one and only job...weird!
      rec.contact_info = create_contact_info(j)

      # CAMPUS_CODE
      rec.campus_code = 'UCB_Campus'

      # ACCOUNT_TYPE
      rec.account_type = 'EXTERNAL'

      # STATUS - always ACTIVE
      rec.status = 'ACTIVE'

      # USER_IDENTIFIERS
      rec.identifiers = create_identifiers

      # USER_ROLES - DROP (according to D.Rez, Alma should assign)
      # USER_STATISTICS - TBD (according to J.Gosselar these have yet to be determined)

      # SET USER ELIGIBILITY
      self.eligible = true
    end

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
      identifiers.push(create_univ_id(ucpath_rec.uid)) if ucpath_rec.uid

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

    def create_contact_info(job)
      c = ContactInfo.new
      c.addresses = create_addresses job
      c.emails = create_emails
      c.phones = create_phones

      c
    end

    private

    def email?
      return false if rec.contact_info.emails.nil?
      return false if rec.contact_info.emails.email_address.nil?
      return false if rec.contact_info.emails.email_address.empty?

      true
    end

    def create_addresses(job)
      create_address(job)
    end

    def create_emails
      create_email
    end

    def create_phones
      create_phone
    end

    # rubocop:disable Metrics/AbcSize
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
    #                                                                #
    # UPDATE: 2024-05-20 (DP-1058)                                   #
    # No longer use the 'berkeleyEduOfficialEmail' that has been     #
    # deprecated by CalNet. Instead use the 'berkeleyedualternateid' #
    # which will always be the official '@berkeley.edu' address      #
    #----------------------------------------------------------------#
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def create_email
      if ldap.nil? || !ldap.berkeleyedualternateid || ldap.berkeleyedualternateid.first == ''
        # return nil if ucpath_rec.email.blank?
        return nil unless ucpath_rec.email

        e = Email.new
        e.preferred = ucpath_rec.email_primary_code
        e.email_address = ucpath_rec.email
      else
        e = Email.new
        e.preferred = 'true'
        e.email_address = ldap.berkeleyedualternateid.first
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
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
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

    # First load all UCPath Employee Data into obj
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    #
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

    def fetch_user
      User.fetch_ucpath_rec(id)
    end

  end
  # rubocop:enable Metrics/ClassLength
end
