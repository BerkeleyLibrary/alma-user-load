require 'ostruct'
require 'nokogiri'
require_relative 'user'
require_relative '../alma'

module UCPath
  class User

    attr_accessor :id
    attr_accessor :obj
    attr_accessor :user
    attr_accessor :jobs

    def initialize(id)
      @id = id
      
      # We'll assume this user is ineligible until we know otherwise
      @eligible = false
      
      # Create an open struct that will munge all those data sources into a single user object
      @obj = OpenStruct.new



      # Fetch the UCPath user and jobs records:
      @user = Nokogiri::XML(fetch_user)
      @jobs = Nokogiri::XML(fetch_jobs)

      # Let's go ahead and munge the shit out all this and build our obj...
      objectify



      puts "----------------- USER ------------------"
      puts "OBJ: #{@obj}"
      # puts "JOBS:\n#{@jobs}\n--"
      
      #puts "GETTING LDAP...."
      # Fetch the LDAP user record:
      # NOTE - id won't work... I need to get the other id from the barcode field I think!
      @ldap = LDAP::API.fetch_user(@obj['uid'])
      #puts "LDAP:\n#{@ldap}\n--"


      # Fetch the Alma user record:
      # @alma = Alma::User(id)
    
      #puts "\nALMA:\n#{@alma}\n--"
      
      puts "--------------------------------------"

      exit
    end

    # Todo - Flesh this logic out!
    def is_eligible?
      true
    end

    def objectify
      Config.ucpath_employee_fields.each do |f|
        name = f['name']
        xpath = f['xpath']
        status = f['status'] || 'OPTIONAL'

        # puts user.xpath("//emp:employees/emp:employee/p:identifiers/r:identifier[r:type='hr-employee-id']/r:id").text

        value = user.xpath(xpath).text || ''

        if status == 'REQUIRED' && value.blank?
          # TODO - LOG ERROR : id - MISSING REQUIRED FIELD: name
        end

        obj[name] = value if value

      end

      # TODO - Need to fix this... it's crap. I think JSON would be easier to deal with than this XML shit
      Config.ucpath_job_fields.each do |f|
        name = f['name']
        xpath = f['xpath']
        status = f['status'] || 'OPTIONAL'

        # puts user.xpath("//emp:employees/emp:employee/p:identifiers/r:identifier[r:type='hr-employee-id']/r:id").text

        next if xpath.blank?

        value = user.xpath(xpath).text || ''

        if status == 'REQUIRED' && value.blank?
          # TODO - LOG ERROR : id - MISSING REQUIRED FIELD: name
        end

        obj[name] = value if value

      end
    end

    def print_obj
      puts "---------- user | line# 59 ------------"
      puts "obj.inspect : #{obj.inspect}"
      puts "--------------------------------------"
    end

    def print 
      puts "\n-----------------------------"
      puts "UCPATH::User\n"
      # puts "#{user.inspect}"
      puts "ID TYPE:"
      # puts user.('//p:familyName').map(&:text)
      #puts "ID: " + user.("//emp:employee/p:identifiers/r:identifier[r:type/text()='hr-employee-id']/r:id")
      # puts "GIVEN NAME  : #{user['response'][0]['names'][0]['givenName']}"
      # puts "FAMILY NAME : #{user['response'][0]['names'][0]['familyName']}"
      #puts "GIVEN NAME  : #{user['names'][0]['givenName']}"
      #puts "FAMILY NAME : #{user['names'][0]['familyName']}"
      puts "---"
      #puts "jobs: #{jobs}"

      puts "-----------------------------"
    end

    def to_xml
      # First define the XML Fragment (we'll build up the user nodes first)
      user_doc = Alma::XMLFragment.new

      # We need our *fragments* root element:
      user_element = user_doc.create_element('user')

      user_doc.add_element(user_element, 'record_type', 'PUBLIC')
      user_doc.add_element(user_element, 'primary_id', id)
      user_doc.add_element(user_element, 'first_name', obj.first_name)
      user_doc.add_element(user_element, 'middle_name', obj.middle_name)
      user_doc.add_element(user_element, 'last_name', obj.last_name)

      # TODO - Fix this (not sure if I need to create it or if it's in the data):
      user_doc.add_element(user_element, 'full_name', obj.formatted_name)

      # TODO - user_group needs to be dynamic:
      user_doc.add_element(user_element, 'user_group', 'FACULTY')

      # TODO - Confirm hardcode to UCB Campus:
      user_doc.add_element(user_element, 'campus_code', 'UCB Campus')

      # TODO - Dynamically set dates:
      user_doc.add_element(user_element, 'expiry_date', '2022-12-17')
      user_doc.add_element(user_element, 'purge_date', '2022-12-17')

      user_doc.add_element(user_element, 'account_type', 'EXTERNAL')
      user_doc.add_element(user_element, 'status', 'ACTIVE')
      
      # contact_info
      # probably break contact out to a separat function
      # (and then probably break address, email and phone into their own)
      contact_e = user_doc.create_element('contact_info')

      # Build Address:
      addresses_e = user_doc.create_element('addresses')
      address_e = user_doc.create_element('address')
      address_e['preferred'] = 'true'
      address_e['segment_type'] = 'Internal'
      address_line1_e = user_doc.create_element('line1', 'obj')
      address_line2_e = user_doc.create_element('line2', 'init_value')
      address_city_e = user_doc.create_element('city', 'Antioch')
      address_state_e = user_doc.create_element('state', 'CA')
      address_postal_e = user_doc.create_element('postal_code', '94531')
      address_country_e = user_doc.create_element('country', 'USA')
      address_note_e = user_doc.create_element('address_note', 'Whatever')
      address_start_e = user_doc.create_element('address_start', '2021-07-27')
      address_end_e = user_doc.create_element('address_end', '2023-10-31')
      # Create Address Types:
      address_types_e = user_doc.create_element('address_types')
      address_type_e = user_doc.create_element('address_type', 'school')
      Alma::XMLFragment.child_to_parent(address_type_e, address_types_e)
      # Assemble Address:
      Alma::XMLFragment.child_to_parent(address_line1_e, address_e)
      Alma::XMLFragment.child_to_parent(address_line2_e, address_e)
      Alma::XMLFragment.child_to_parent(address_city_e, address_e)
      Alma::XMLFragment.child_to_parent(address_state_e, address_e)
      Alma::XMLFragment.child_to_parent(address_postal_e, address_e)
      Alma::XMLFragment.child_to_parent(address_country_e, address_e)
      Alma::XMLFragment.child_to_parent(address_note_e, address_e)
      Alma::XMLFragment.child_to_parent(address_start_e, address_e)
      Alma::XMLFragment.child_to_parent(address_end_e, address_e)
      Alma::XMLFragment.child_to_parent(address_types_e, address_e)
      Alma::XMLFragment.child_to_parent(address_e, addresses_e)
      Alma::XMLFragment.child_to_parent(addresses_e, contact_e)
      

      # Create Email:
      emails_e = user_doc.create_element('emails')
      email_e = user_doc.create_element('email')
      email_e['preferred'] = 'true'
      email_e['segment_type'] = 'Internal'
      email_address_e = user_doc.create_element('email_address', obj.email)
      # Create Email Types:
      email_types_e = user_doc.create_element('email_types')
      email_type_e = user_doc.create_element('email_type', obj.email_type)
      Alma::XMLFragment.child_to_parent(email_type_e, email_types_e)
      # Assemble Email:
      Alma::XMLFragment.child_to_parent(email_address_e, email_e)
      Alma::XMLFragment.child_to_parent(email_types_e, email_e)
      Alma::XMLFragment.child_to_parent(email_e, emails_e)
      Alma::XMLFragment.child_to_parent(emails_e, contact_e)


      # Build Phone:
      phones_e = user_doc.create_element('phones')
      phone_e = user_doc.create_element('phone')
      phone_e['preferred'] = obj.phone_primary_code
      phone_e['preferred_sms'] = 'false'
      phone_e['segment_type'] = 'External'
      phone_number_e = user_doc.create_element('phone_number', obj.phone_number)
      # Create phone Types:
      phone_types_e = user_doc.create_element('phone_types')
      phone_type_e = user_doc.create_element('phone_type', obj.phone_type)
      Alma::XMLFragment.child_to_parent(phone_type_e, phone_types_e)
      # Assemble phone:
      Alma::XMLFragment.child_to_parent(phone_number_e, phone_e)
      Alma::XMLFragment.child_to_parent(phone_types_e, phone_e)
      Alma::XMLFragment.child_to_parent(phone_e, phones_e)
      Alma::XMLFragment.child_to_parent(phones_e, contact_e)

      
      
      Alma::XMLFragment.child_to_parent(contact_e, user_element)
      user_doc.append(user_element)

      user_doc.xml
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
      
      # TODO - make these dynamic
      start_date = '2021-11-05'
      end_date   = '2021-11-05'

      log = User.change_log(start_date, end_date) || nil
    end


    def fetch_user
      User.fetch_user_by_id(id)
    end

    def fetch_jobs
      User.fetch_jobs_by_id(id)
    end

  end
end


__END__

<?xml version="1.0" encoding="UTF-8"?>
<ar:apiResponse xmlns:e="http://bmeta.berkeley.edu/common/eventV0.xsd" xmlns:t="http://bmeta.berkeley.edu/student/termV0.xsd" xmlns:r="http://bmeta.berkeley.edu/common/referenceV0.xsd" xmlns:c="http://bmeta.berkeley.edu/common/contactV0.xsd" xmlns:emp="http://bmeta.berkeley.edu/humanResources/employeeV0.xsd" xmlns:comp="http://bmeta.berkeley.edu/humanResources/compensationV0.xsd" xmlns:p="http://bmeta.berkeley.edu/common/personV2.xsd" xmlns:dep="http://bmeta.berkeley.edu/common/departmentV0.xsd" xmlns:jc="http://bmeta.berkeley.edu/humanResources/jobCodeV0.xsd" xmlns:ar="http://bmeta.berkeley.edu/common/apiResponseV1.xsd" xmlns:pos="http://bmeta.berkeley.edu/humanResources/positionV0.xsd" xmlns:d="http://bmeta.berkeley.edu/common/documentV1.xsd">
  <ar:source>UCB-HR-PATH-DB</ar:source>
  <ar:correlationId>1a5d34b2-e34f-4403-923a-a469e74aa0a6</ar:correlationId>
  <ar:timeStamp>2021-12-02T19:34:58.351Z</ar:timeStamp>
  <ar:httpStatus>
    <r:code>200</r:code>
    <r:description>OK</r:description>
  </ar:httpStatus>
  <ar:response>
    <emp:employees>
      <emp:employee>
        <p:identifiers>
          <r:identifier>
            <r:type>hr-employee-id</r:type>
            <r:id>10040408</r:id>
          </r:identifier>
          <r:identifier>
            <r:type>campus-uid</r:type>
            <r:id>1681801</r:id>
          </r:identifier>
          <r:identifier>
            <r:type>calnet-id</r:type>
            <r:id>jamesford</r:id>
          </r:identifier>
          <r:identifier>
            <r:type>campus-solutions-id</r:type>
            <r:id>3035388240</r:id>
          </r:identifier>
        </p:identifiers>
        <p:names>
          <p:name>
            <p:type>
              <r:code>PRI</r:code>
              <r:description>Primary</r:description>
            </p:type>
            <p:familyName>Almaraz</p:familyName>
            <p:givenName>John</p:givenName>
            <p:middleName>K</p:middleName>
            <p:lastChangedBy>
              <r:id>10135169</r:id>
            </p:lastChangedBy>
            <p:fromDate>2019-05-20</p:fromDate>
          </p:name>
        </p:names>
        <p:addresses>
          <c:address/>
        </p:addresses>
        <p:phones>
          <c:phone>
            <c:type>
              <r:code>BUSN</r:code>
              <r:description>Business - Primary</r:description>
            </c:type>
            <c:number>510/987-0457</c:number>
            <c:primary>false</c:primary>
          </c:phone>
          <c:phone/>
          <c:phone>
            <c:type>
              <r:code>WORK</r:code>
              <r:description>Work - Other Location</r:description>
            </c:type>
            <c:number>510/987-0457</c:number>
            <c:primary>false</c:primary>
          </c:phone>
        </p:phones>
        <p:emails>
          <c:email>
            <c:type>
              <r:code>BUSN</r:code>
              <r:description>Business</r:description>
            </c:type>
            <c:emailAddress>UCPATH.Tester@universityofcalifornia.edu</c:emailAddress>
            <c:primary>true</c:primary>
          </c:email>
          <c:email/>
        </p:emails>
        <p:usaCountry>
          <p:citizenshipStatus>
            <r:code>1</r:code>
            <r:description>US Citizen</r:description>
          </p:citizenshipStatus>
        </p:usaCountry>
        <p:education>
          <p:highestLevel>
            <r:code>A</r:code>
            <r:description>A-Not Indicated</r:description>
          </p:highestLevel>
        </p:education>
        <p:foreignCountries>
          <p:foreignCountry>
            <r:code>DEF</r:code>
            <r:description>Default Country - Conversion</r:description>
          </p:foreignCountry>
        </p:foreignCountries>
      </emp:employee>
    </emp:employees>
  </ar:response>
</ar:apiResponse>


<user>
<record_type>PUBLIC</record_type>
<primary_id>10159427</primary_id>
<first_name>Aanika</first_name>
<middle_name/>
<last_name>Shah</last_name>
<full_name></full_name>
<user_group>FACULTY</user_group>
<campus_code>UCB Campus</campus_code>
<expiry_date>2023-10-31</expiry_date>
<purge_date>2023-10-31</purge_date>
<account_type>EXTERNAL</account_type>
<status>ACTIVE</status>
<contact_info>
  <addresses>
    <address preferred="true" segment_type="Internal">
      <line1>DS Educ Prgs _ Commons</line1>
      <line2>Barrows Hall-F03-94720</line2>
      <city>Berkeley</city>
      <state_province>CA</state_province>
      <postal_code>94720</postal_code>
      <country></country>
      <address_note></address_note>
      <start_date>2021-07-27</start_date>
      <end_date>2023-10-31</end_date>
      <address_types>
        <address_type>school</address_type>
      </address_types>
    </address>
  </addresses>
  <emails>
    <email preferred="true" segment_type="Internal">
      <email_address>aanika.shah@berkeley.edu</email_address>
      <email_types>
        <email_type>school</email_type>
      </email_types> 
    </email>
  </emails>
  <phones>
    <phone preferred="true" preferred_sms="false" segment_type="External">
      <phone_number>650-440-1882</phone_number>
      <phone_types>
      <phone_type>office</phone_type>
      </phone_types>
    </phone>
  </phones>
</contact_info>
<user_identifiers>
  <user_identifier segment_type="Internal">
    <id_type>BARCODE</id_type>
    <value>013228482</value>
    <status>ACTIVE</status>
  </user_identifier>
  <user_identifier segment_type="Internal">
    <id_type>BARCODE</id_type>
    <value>E10159427</value>
    <status>ACTIVE</status>
  </user_identifier>
  <user_identifier segment_type="Internal">
    <id_type>BARCODE</id_type>
    <value>A3228482</value>
    <status>ACTIVE</status>
  </user_identifier>
  <user_identifier segment_type="Internal">
    <id_type>BARCODE</id_type>
    <value>1557787</value>
    <status>ACTIVE</status>
  </user_identifier>
</user_identifiers>
<user_roles>
  <user_role>
    <status>NEW</status>
    <scope></scope>
    <role_type>200</role_type>
    <expiry_date>2023-10-31</expiry_date>
  </user_role>
</user_roles>
<user_statistics>
  <user_statistic segment_type="External">
    <statistic_category>UCB</statistic_category>
    <category_type></category_type>
    <statistic_note>DSDDO</statistic_note>
  </user_statistic>
  <user_statistic segment_type="External">
    <statistic_category>UCB</statistic_category>
    <category_type></category_type>
    <statistic_note>Faculty/Academic Staff</statistic_note>
  </user_statistic>
</user_statistics>
</user>
