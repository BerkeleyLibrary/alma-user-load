
require 'json'
require 'active_support/core_ext/hash' # from_xml
#require_relative 'api'

module SIS
  # Alma User object in all it's naked glory...
  
  class User
    #include Alma::API
    attr_accessor :user

    def initialize
      @user = {}
    end

    def set_field(field, value = nil)
      user[field] = value
    end

    def to_xml
      # convert our @user hash to an Alma XML user
    end

    def print
      puts user
    end

    def create_user
      user['REG.STUDENT_ID']                          =  '12345678'
      user['REG.TERM_ID']                             =  '202101001'
      user['REG.REGISTERED']                          =  'true'
      user['REG.ELIGIBLETOREGISTER']                  =  'true'
      user['REG.WITHCNCL_TYPE_CODE']                  =  'X'
      user['REG.ACADCAREER_CODE']                     =  'Y'
      user['MAJOR.ACADPLAN_DESCR']                    =  'Fun'
      user['PRIM_NAME.NAME_FAMILYNAME']               =  'Family-Name'
      user['PRIM_NAME.NAME_GIVENNAME']                =  'Given'
      user['PRIM_NAME.NAME_MIDDLENAME']               =  'Mid'
      user['LOCL_ADDR.ADDRESS_ADDRESS1']              =  '123 Local Place'
      user['LOCL_ADDR.ADDRESS_ADDRESS2']              =  nil
      user['LOCL_ADDR.ADDRESS_CITY']                  =  'Berkeley'
      user['LOCL_ADDR.ADDRESS_STATECODE']             =  'CA'
      user['LOCL_ADDR.ADDRESS_POSTALCODE']            =  '94533'
      user['HOME_ADDR.ADDRESS_ADDRESS1']              =  '1317 Stoney Gorge Way'
      user['HOME_ADDR.ADDRESS_ADDRESS2']              =  nil
      user['HOME_ADDR.ADDRESS_CITY']                  =  'Antioch'
      user['HOME_ADDR.ADDRESS_STATECODE']             =  'CA'
      user['HOME_ADDR.ADDRESS_POSTALCODE']            =  '94531'
      user['STUDENT_EMAILV01_VW.EMAIL_EMAILADDRESS']  =  'steve.sullivan@berkeley.edu'
      user['STUDENT_PHONEV01_VW.PHONE_NUMBER']        =  '925-234-0409'
      user['PREF_NAME.NAME_FAMILYNAME']               =  'Steve'
      user['PREF_NAME.NAME_GIVENNAME']                =  'Just'
      user['PREF_NAME.NAME_MIDDLENAME']               =  nil
      user['STU_ID.IDENTIFIER_ID']                    =  '12345678'
    end
  end
end


__END__

REG.STUDENT_ID                                            =>  primary_id?
REG.TERM_ID                                               =>  ???
REG.REGISTERED                                            =>  ???
REG.ELIGIBLETOREGISTER                                    =>  ???
REG.WITHCNCL_TYPE_CODE                                    =>  ???
REG.ACADCAREER_CODE                                       =>  ???
MAJOR.ACADPLAN_DESCR                                      =>  ???
PRIM_NAME.NAME_FAMILYNAME                                 =>  last_name
PRIM_NAME.NAME_GIVENNAME                                  =>  first_name
PRIM_NAME.NAME_MIDDLENAME                                 =>  middle_name
LOCL_ADDR.ADDRESS_ADDRESS1                                =>  contact_info>*address>line1 (where address_type: value == ???)
LOCL_ADDR.ADDRESS_ADDRESS2 | LOCL_ADDR.ADDRESS_ADDRESS3   =>  contact_info>address>line2 |contact_info>address>line3
LOCL_ADDR.ADDRESS_CITY                                    =>  contact_info>address>city
LOCL_ADDR.ADDRESS_STATECODE                               =>  contact_info>address>state_province
LOCL_ADDR.ADDRESS_POSTALCODE                              =>  contact_info>address>postal_code                                     
HOME_ADDR.ADDRESS_ADDRESS1                                =>  contact_info>address>line1 (where address_type: value == "home")
HOME_ADDR.ADDRESS_ADDRESS2 | HOME_ADDR.ADDRESS_ADDRESS3   =>  contact_info>address>line2
HOME_ADDR.ADDRESS_CITY                                    =>  contact_info>address>city
HOME_ADDR.ADDRESS_STATECODE                               =>  contact_info>address>state_province
HOME_ADDR.ADDRESS_POSTALCODE                              =>  contact_info>address>postal_code
STUDENT_EMAILV01_VW.EMAIL_EMAILADDRESS                    =>  contact_info>*email>email_address
STUDENT_PHONEV01_VW.PHONE_NUMBER                          =>  contact_info>*phone>phone_number
PREF_NAME.NAME_FAMILYNAME                                 =>  pref_last_name
PREF_NAME.NAME_GIVENNAME                                  =>  pref_first_name
PREF_NAME.NAME_MIDDLENAME                                 =>  pref_middle_name
STU_ID.IDENTIFIER_ID                                      =>  ???