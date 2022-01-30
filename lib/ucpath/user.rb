require 'date'
require 'json'
require 'ostruct'
require 'jsonpath'
require 'nokogiri'
require_relative 'user'
require_relative '../alma'

module UCPath
  class User

    attr_accessor :id
    attr_accessor :rec
    attr_accessor :user
    attr_accessor :jobs

    # NOT SURE IF META IS NEEDED...NEED A WAY OF TRACKING THINGS LIKE
    # ERRORS AND WARNINGS FOR A RECORD
    attr_accessor :meta
    
    attr_accessor :ldap
    attr_accessor :eligible
    attr_accessor :ucpath_rec

    Identifier = Struct.new(:segment_type, :id_type, :value, :status)
    ContactInfo = Struct.new(:addresses, :emails, :phones)
    Address = Struct.new(:preferred, :line1, :line2, :city, :state_province, :postal_code, :country, :address_note, :start_date, :end_date, :address_types)
    Email = Struct.new(:preferred, :email_address, :email_types)
    Phone = Struct.new(:preferred, :preferred_sms, :phone_number, :phone_types)

    def initialize(id)
      @id = id
      logger.info "#{id} - Begin processing record"
      
      @meta = {}

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
      parse_user

      logger.info "#{id} - Fetching ucpath jobs data"
      @jobs = fetch_jobs
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

      logger.info "#{id} - Eligible: #{self.is_eligible?}"
    end

    def is_eligible?
      eligible
    end


    #----------------------------------------------------------------#
    # CREATE A FINAL RECORD THAT CAN BE USED FOR GENERATING XML
    # TODO - probably want to move this into a separate class
    #        "AlmaUser" or something like that, then I can reuse
    #        most of the code when I setup SIS.
    def create_user_record
      rec.primary_id = ucpath_rec.ucpath_employee_id

      #----------------------------------------------------------------#
      # STUDENT CHECK - berkeleyeduaffiliations in Student Affiliation (ldap_fields.yml)
      if ldap && ldap.berkeleyeduaffiliations
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
      if ucpath_rec.first_name && ucpath_rec.last_name
        rec.first_name = ucpath_rec.first_name
        rec.last_name = ucpath_rec.last_name
        rec.middle_name = ucpath_rec.middle_name if (ucpath_rec.middle_name)
      else
        rec.first_name = ldap.givenName.first
        rec.first_name = ldap.sn.first
      end

      #----------------------------------------------------------------#
      # USER_GROUP:
      # Probably spin this off to a separate function!
      rec.user_group = nil

      ineligible_reasons = []

      ucpath_rec.jobs.each do |j|

        # Assume this job is eligible - this is based on the 3 criteria below
        job_eligible = true

        # 1. hrStatus/code = A
        unless j.hr_status_code == 'A'
          ineligible_reasons.push("#{rec.primary_id} - Ineligible: HR status code: '#{j.hr_status_code}' - must be 'A'")
          job_eligible = false 
        end
        
        # 2. If their Job record has an expectedEndDate, it must be on or after today's date.
        unless j.expected_end_date.blank?
          ineligible_reasons.push("#{rec.primary_id} - Ineligible: expected_end_date not in the future")
          job_eligible = false if Date.iso8601(j.expected_end_date) <= Date.today
        end
        
        # 3. If their organizationRelationship/code = 'CWR' their jobCode must be within 
        #    the Visiting Scholar category.
        unless j.org_relationship_code.blank?
          if j.org_relationship_code == 'CWR'
            ineligible_reasons.push("#{rec.primary_id} - Ineligible: org code CWR has non visiting scholar job code")
            job_eligible = false unless Config.check_ucpath_code('Visiting Scholar Job Code', j.job_code)
          end
        end
        
        
        if job_eligible
          # Found eligible job - clear out any previous ineligible reasons
          ineligible_reasons = nil
          
          # USER_GROUP
          if Config.check_ucpath_code('Library Staff Dept Code Prefix', j.dept_code) || 
            Config.check_ucpath_code('Library Staff Job Code', j.job_code)
            rec.user_group = 'LIBSTAFF'
          elsif Config.check_ucpath_code('Postdoc Job Code', j.job_code)
            rec.user_group = 'UCB POST'
          elsif Config.check_ucpath_code('Visiting Scholar Job Code', j.job_code)
            rec.user_group = 'UCBVISSCHOL'
          elsif Config.check_ucpath_code('Academic Classification Indic', j.classification_indc) &&
              Config.check_ucpath_code('UC Extension Faculty', j.dept_code)
            rec.user_group = 'UCEXT'
          elsif Config.check_ucpath_code('Academic Classification Indic', j.classification_indc) ||
              Config.check_ucpath_code('Emeritus Job Code', j.job_code)
            rec.user_group = 'FACULTY'
          elsif Config.check_ucpath_code('Executive Classification Indic', j.classification_indc)
            rec.user_group = 'EXECUTIVE'
          else
            rec.user_group = 'NONACAD'
          end

          # EXPIRTY_DATE
          if j.expected_end_date.blank?
            rec.expiry_date = create_expected_end_date
          else 
            rec.expiry_date = j.expected_end_date
          end

          # PURGE_DATE (expiry date plus one year)
          rec.purge_date = Date.iso8601(rec.expiry_date).next_year.to_s

          # Oddly, addresses, emails and phones are taken from this one and only job...weird!
          rec.contact_info = create_contact_info(j)

          # CAMPUS_CODE
          # TODO - Confirm this is hardcoded? (I doubt it)
          rec.campus_code = 'UCB Campus'
    
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
      end

      if ineligible_reasons
        ineligible_reasons.each do |r|
          logger.info r
        end
      end

    end

    def create_identifiers
      identifiers = []

      # hr-employee-id : Note add 'E' prefix
      identifiers.push(create_identifier(ucpath_rec.ucpath_employee_id, 'E')) unless ucpath_rec.ucpath_employee_id.blank?
      
      # legacy-hr-employee-id
      identifiers.push(create_identifier(ucpath_rec.legacy_employee_id)) unless ucpath_rec.legacy_employee_id.blank?
      identifiers.push(create_identifier(ucpath_rec.legacy_employee_id.chars.last(7).join, 'A')) unless ucpath_rec.legacy_employee_id.blank?
      
      # campus-uid
      identifiers.push(create_identifier(ucpath_rec.uid)) unless ucpath_rec.uid.blank?

      identifiers
    end

    def create_identifier(identifier, prefix=nil)
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

      
      # CONFIRM THIS IS HARDCODED TO 'SCHOOL'
      a.address_types = 'school'

      # RETURN our address struct
      a
    end

    
    # TODO - Email addresses must be checked for structural validity.

    #----------------------------------------------------------------#
    # Email                                                          #
    # Take first from the LDAP berkeleyEduOfficialEmail field,       #
    # then if not found use the primary email address from the       #
    # Employee record if it exists, otherwise use any other email    #
    # address from the record.                                       #
    #----------------------------------------------------------------#
    def create_email

      unless !ldap.berkeleyeduofficialemail || ldap.berkeleyeduofficialemail.first.blank?
        e = Email.new
        e.preferred = 'true'
        e.email_address = ldap.berkeleyeduofficialemail.first
        e.email_types = 'school'        
      else
        return nil if ucpath_rec.email.blank?

        e = Email.new
        e.preferred = ucpath_rec.email_primary_code
        e.email_address = ucpath_rec.email
        e.email_types = ucpath_rec.email_type
      end

      e
    end


    #----------------------------------------------------------------#
    # Phone Number                                                   #
    # Take first from the LDAP telephoneNumber field, then if not    #
    # found use the primary number from the Employee record if it    #
    # exists, otherwise use any other phone number from the record.  #
    #----------------------------------------------------------------#
    def create_phone

      unless !ldap.telephonenumber || ldap.telephonenumber.first.blank?
        telephone = format_phone ldap.telephonenumber.first
        
        p = Phone.new
        p.preferred = 'true'
        p.preferred_sms = 'false'
        p.phone_number = telephone || nil
        p.phone_types = 'office'
      else
        return nil if ucpath_rec.phone_number.blank?
        telephone = format_phone ucpath_rec.phone_number
        
        p = Phone.new
        if ucpath_rec.phone_number.blank?
          p.preferred = ucpath_rec.phone_primary_code
        else
          p.preferred = 'true'
        end
        p.preferred_sms = 'false'
        p.phone_number = telephone || nil
        p.phone_types = ucpath_rec.phone_type || nil
      end

      p      
    end

    #----------------------------------------------------------------#
    # Regular Expression Jujitsu:                                    #
    # Apparently Alvin's run into some severely mutilated phone      #
    # numbers - the Following series of REGEXs were cribbed and      #
    # translated from 20111130_Current_Procedures document on bdrive #
    #----------------------------------------------------------------#
    def format_phone(telephone)
      preserved_number = telephone
      telephone = telephone.sub(/^\+1\s+/, '')
      telephone = telephone.sub(/^1-/, '')
      telephone = telephone.sub(/^1\s+/, '')
      telephone = telephone.sub(/\s+\([^\(\)]+\)$/, '')
      telephone = telephone.gsub('.', '-')
      telephone = telephone.sub(/-x\d+$/, '')
      telephone = telephone.gsub('/', '-')
      telephone = telephone.gsub('(', '')
      telephone = telephone.gsub(')', '')
      telephone = telephone.sub(/^\s+/, '')
      telephone = telephone.sub(/\s+$/, '')

      # Let's see if we managed to torture the number into submission...
      if telephone =~ /^\d{3}-\d{3}-\d{4}$/
        # YES!  111-222-3333
        telephone = telephone
      elsif telephone =~ /^(\d{3})[- ](\d{3})-(\d{4})$/
        # A little wishy washy:  111 222-3333
        telephone = "#{$1}-#{$2}-#{$3}"
      elsif telephone =~ /^(\d{3})(\d{3})(\d{4})$/
        # Okay I guess:  1112223333
        telephone = "#{$1}-#{$2}-#{$3}"
      elsif telephone =~ /^(\d{3})[ -]?(\d{4})$/
        # Lazy...no area code:  111-2222
        telephone = "510-#{$1}-#{$2}"
      elsif telephone =~ /^(\d)[ -]?(\d{4})$/
        # WTF!?!  1 2222
        telephone = "510-64#{$1}-#{$2}"
      else
        # Apparently we have not... Log it
        logger.info "#{id} - Failed to process phone number: #{preserved_number}"
        return nil
      end

      telephone
    end




    

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

      if d.month < change_month
        expiration_year = d.year + expiration_year_interval - 1
      else
        expiration_year = d.year + expiration_year_interval
      end

      expiration_date = "#{expiration_year.to_s}-#{expiration_month_day}"
      
    end

    # First load all UCPath Employee Data into obj
    def parse_user
      
      Config.ucpath_employee_fields.each do |f|
        name = f['name']
        jpath = f['jpath']
        alt_jpath = f['alt_jpath']
        status = f['status'] || 'OPTIONAL'

        next unless jpath

        value = JsonPath.on(@user, jpath).first || ''

        # If field has an alternatate path (E.G., non primary phone)
        if value.blank? && alt_jpath
          value = JsonPath.on(@user, alt_jpath).first || ''
        end

        if status == 'REQUIRED' && value.blank?
          logger.error "#{id} - Missing required field: #{name}"
        end

        ucpath_rec[name] = value if value
      end

    end

    # TODO - I may need to set this up to always have the primary job
    #        as the first element in the array
    # We'll throw all the jobs into an array of open structs:
    def parse_jobs
      ucpath_rec['jobs'] = []
      
      # Query @jobs for the actual jobs
      job_data = JsonPath.on(@jobs, '$..response[*].jobs')

      return nil unless job_data.count > 0

      job_data.first.each_with_index do |job, idx|
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
          status = f['status'] || 'OPTIONAL'
  
          next unless jpath
  
          # value = user.xpath(xpath).text || ''
          value = JsonPath.on(j, jpath).first || ''
  
          if status == 'REQUIRED' && value.blank?
            logger.error "#{id} - Job Missing Required Field: #{name}"
          end
  
          job[name] = value if value
        end

        ucpath_rec['jobs'].push(job)
      end

    end

    

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
    def self.fetch_change_log(start_date, end_date)
      log = User.change_log(start_date, end_date) || nil
    end

    def fetch_user
      User.fetch_ucpath_rec(id)
    end

    def fetch_jobs
      User.fetch_ucpath_jobs(id)
    end

  end
end
