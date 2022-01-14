require 'date'
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

    # NOT SURE I META IS NEEDED...NEED A WAY OF TRACKING THINGS LIKE
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
      
      @meta = {}

      # We'll assume this user is ineligible until we know otherwise
      @eligible = false


      #----------------------------------------------------------------#
      # THESE RECORDS ARE A BIT MORE FLEXIBLE AND THUS USING OPENSTRUCTS
      @rec = OpenStruct.new
      @ucpath_rec = OpenStruct.new

      
      #----------------------------------------------------------------#
      # FETCH & PARSE UCPATH DATA
      @user = fetch_user
      parse_user

      @jobs = fetch_jobs
      parse_jobs
      
      
      #----------------------------------------------------------------#
      # FETCH LDAP
      @ldap = LDAP::API.fetch_ldap_rec(@ucpath_rec.uid)
      

      #----------------------------------------------------------------#
      # FETCH ALMA RECORD (NOT SURE IF I'LL NEED THIS OR NOT....)
      # @alma_rec = Alma::User.new
      # @alma_rec.load_user(id)
      # puts "Last Name: #{@alma_rec.user.last_name}"
    

      #----------------------------------------------------------------#
      # CREATE THE USER RECORD (@rec) FROM THE ABOVE DATA SOURCES
      create_user_record
    end

    def is_eligible?
      eligible
    end


    #----------------------------------------------------------------#
    # CREATE A FINAL RECORD THAT CAN BE USED FOR GENERATING XML
    def create_user_record
      rec.primary_id = ucpath_rec.ucpath_employee_id


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

      ucpath_rec.jobs.each do |j|

        # Assume this job is eligible - this is based on the 3 criteria below
        job_eligible = true

        # 1. hrStatus/code = A
        unless j.hr_status_code == 'A'
          job_eligible = false 
          puts "INELIGIBLE : #{rec.primary_id} - ineligible HR status code: '#{j.hr_status_code}' - must be 'A'"
          
          # meta['ineligible_reasons'] = ''
        end
        
        # 2. If their Job record has an expectedEndDate, it must be on or after today's date.
        unless j.expected_end_date.blank?
          job_eligible = false if Date.iso8601(j.expected_end_date) <= Date.today
          puts "INELIGIBLE : #{rec.primary_id} - expected_end_date in the past"
        end
        
        # 3. If their organizationRelationship/code = 'CWR' their jobCode must be within 
        #    the Visiting Scholar category.
        unless j.org_relationship_code.blank?
          if j.org_relationship_code == 'CWR'
            puts "INELIGIBLE : #{rec.primary_id} - org code CWR has non visiting scholar job code"
            job_eligible = false unless Config.check_ucpath_code('Visiting Scholar Job Code', j.job_code)
          end
        end
        
        
        if job_eligible
          puts "ELIGIBLE : #{rec.primary_id} - Found eligible job!"
          
          # USER_GROUP
          if Config.check_ucpath_code('Library Staff Dept Code Prefix', j.department_code) || 
            Config.check_ucpath_code('Library Staff Job Code', j.job_code)
            rec.user_group = 'LIBSTAFF'
          elsif Config.check_ucpath_code('Postdoc Job Code', j.job_code)
            rec.user_group = 'UCB POST'
          elsif Config.check_ucpath_code('Visiting Scholar Job Code', j.job_code)
            rec.user_group = 'UCBVISSCHOL'
          elsif Config.check_ucpath_code('Academic Classification Indic', j.classification_code) &&
              Config.check_ucpath_code('UC Extension Faculty', j.department_code)
            rec.user_group = 'UCEXT'
          elsif Config.check_ucpath_code('Academic Classification Indic', j.classification_code) ||
              Config.check_ucpath_code('Emeritus Job Code', j.job_code)
            rec.user_group = 'FACULTY'
          elsif Config.check_ucpath_code('Executive Classification Indic', j.classification_code)
            rec.user_group = 'EXECUTIVE'
          else
            rec.user_group = 'NONACAD'
          end

          # TODO - REMOVE:
          puts "---------- user | line# 131 ------------"
          puts "rec.user_group        : #{rec.user_group}"
          puts "j.classification_code : #{j.classification_code}"
          puts "j.job_code            : #{j.job_code}"
          puts "--------------------------------------"

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
    end

    def create_identifiers
      identifiers = []

      # hr-employee-id : Note add 'E' prefix
      identifiers.push(create_identifier(ucpath_rec.ucpath_employee_id, 'E')) unless ucpath_rec.ucpath_employee_id.blank?
      
      # legacy-hr-employee-id
      identifiers.push(create_identifier(ucpath_rec.legacy_employee_id)) unless ucpath_rec.legacy_employee_id.blank?
      
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

      a.preferred = 'yes'
      a.line1 = job.dept_desc if job.dept_desc
      a.line2 = job.location_description if job.location_description
      a.city = 'Berkeley'
      a.state_province = 'CA'
      a.postal_code = '94720'

      # Example file had all empty country fields... leave blanK?
      # a.country = 'England'

      #----------------------------------------------------------------#
      # ADDRESS_NOTE:
      # Take first the berkeleyEduPrimaryDeptUnit from LDAP if it 
      # exists, otherwise use department/code
      if ldap.berkeleyEduPrimaryDeptUnit
        a.address_note = ldap.berkeleyEduPrimaryDeptUnit.first
      else
        a.address_note = job.dept_code || nil
      end

      # TODO - CONFIRM LOGIC FOR START DATE
      a.start_date = Date.iso8601(rec.expiry_date).next_year.to_s
      a.end_date = Date.iso8601(rec.expiry_date).next_year.to_s

      puts "---------- user | line# 274 ------------"
      puts "rec.expiry_date     : #{rec.expiry_date}"
      puts "a.start_date        : #{a.start_date}"
      puts "a.end_date          : #{a.end_date}"
      puts "j.expected_end_date : #{job.expected_end_date}"
      puts "--------------------------------------"
      
      # CONFIRM THIS IS HARDCODED TO 'SCHOOL'
      a.address_types = 'school'

      # RETURN our address struct
      a
    end

    def create_email
      return nil if ucpath_rec.email.blank?

      e = Email.new
      e.preferred = ucpath_rec.email_primary_code
      e.email_address = ucpath_rec.email
      e.email_types = ucpath_rec.email_type

      e
    end

    def create_phone
      return nil if ucpath_rec.phone_primary_code.blank?

      p = Phone.new
      p.preferred = ucpath_rec.phone_primary_code
      p.preferred_sms = nil
      p.phone_number = ucpath_rec.phone_number || nil
      p.phone_types = ucpath_rec.phone_type || nil

      p
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

    def parse_user
      # First load all UCPath Employee Data into obj
      
      Config.ucpath_employee_fields.each do |f|
        name = f['name']
        jpath = f['jpath']
        status = f['status'] || 'OPTIONAL'

        next unless jpath

        value = JsonPath.on(@user, jpath).first || ''

        if status == 'REQUIRED' && value.blank?
          # TODO - LOG ERROR : id - MISSING REQUIRED FIELD: name
          puts "\n****** ERROR - Missing required field: #{name} ******\n"
        end

        ucpath_rec[name] = value if value
      end

    end

    # TODO - I may need to set this up to always have the primary job
    #        as the first element in the array
    def parse_jobs
      # We'll throw all the jobs into an array of open structs:
      ucpath_rec['jobs'] = []

      # Then load jobs into obj
      JsonPath.on(@jobs, '$..response[*].jobs').each do |j|
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
          value = JsonPath.on(j.first, jpath).first || ''
  
          if status == 'REQUIRED' && value.blank?
            # TODO - LOG ERROR : id - MISSING REQUIRED FIELD: name
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
    def self.fetch_change_log
      
      # TODO - make these dynamic (but also commandline over-ridable)
      start_date = '2021-08-12'
      end_date   = '2021-08-26'

      puts "---------- TESTING ------------"
      puts "start_date : #{start_date}"
      puts "end_date : #{end_date}"
      puts "-------------------------------"

      # log = User.change_log(start_date, end_date) || nil
    end


    def fetch_user
      User.fetch_ucpath_rec(id)
    end

    def fetch_jobs
      User.fetch_ucpath_jobs(id)
    end

  end
end
