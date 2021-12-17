require 'json'
require 'active_support/core_ext/hash' # from_xml
require_relative 'api'

module Alma
  # Alma User object in all it's naked glory...
  
  class User
    include Alma::API
    attr_accessor :user
    
    def initialize
      @user = {}
    end

    def add_field(name, value)
      user[name] = value
    end

    def print(field = nil)
      return  user[field] if field
      user
    end

    def to_xml
      
    end
    

    # Fetch a User From Alma (via API)
    def load_user(id)
      puts "---------->loading user: #{id}"
      # IF JSON:s
      # user = JSON[(Alma::API.fetch_user(id).body)]
      # IF XML:
      # user = Nokogiri::XML(Alma::API.fetch_user(id).body)

      # IF we want to parse the XML into a hash
      u = Hash.from_xml(Alma::API.fetch_user(id).body)

      self.user = u['user']
    end


  end
end


__END__

Example user (Me!) pulled from Alma as XML and then converted to a hash
"user"=>{
  "record_type"=>"PUBLIC",
  "primary_id"=>"10335026",
  "first_name"=>"STEVEN",
  "middle_name"=>"M",
  "last_name"=>"SULLIVAN",
  "full_name"=>"STEVEN M SULLIVAN",
  "user_title"=>{"desc"=>""},
  "job_category"=>{"desc"=>""},
  "job_description"=>nil,
  "gender"=>{"desc"=>""},
  "user_group"=>"LIBSTAFF",
  "campus_code"=>{"desc"=>""},
  "web_site_url"=>nil,
  "cataloger_level"=>"00",
  "preferred_language"=>"en",
  "expiry_date"=>"2023-10-31Z",
  "purge_date"=>"2023-10-31Z",
  "account_type"=>"EXTERNAL",
  "external_id"=>"SIS",
  "password"=>nil,
  "force_password_change"=>nil,
  "status"=>"ACTIVE",
  "status_date"=>"2021-07-25Z",
  "contact_info"=>{
    "addresses"=>{
      "address"=>{
        "preferred"=>"true",
        "segment_type"=>"External",
        "line1"=>"Library Administration",
        "line2"=>"Bancroft Lib (Doe Anx)-F01-94720",
        "city"=>nil,
        "state_province"=>nil,
        "postal_code"=>nil,
        "country"=>{"desc"=>""},
        "address_note"=>nil,
        "address_types"=>{"address_type"=>"home"}
      }
    },
    "emails"=>{
      "email"=>{
        "preferred"=>"true",
        "segment_type"=>"External",
        "email_address"=>"steve.sullivan@berkeley.edu",
        "email_types"=>{"email_type"=>"school"}
      }
    },
    "phones"=>{
      "phone"=>{
        "preferred"=>"true",
        "preferred_sms"=>"false",
        "segment_type"=>"External",
        "phone_number"=>"925-234-0409",
        "phone_types"=>{"phone_type"=>"home"}
      }
    }
  },
  "pref_first_name"=>nil,
  "pref_middle_name"=>nil,
  "pref_last_name"=>nil,
  "pref_name_suffix"=>nil,
  "is_researcher"=>"false",
  "user_identifiers"=>{
    "user_identifier"=>[
      {
        "segment_type"=>"External",
        "id_type"=>"BARCODE",
        "value"=>"1707532",
        "status"=>"ACTIVE"
      },
      {
        "segment_type"=>"External",
        "id_type"=>"BARCODE",
        "value"=>"e10335026",
        "status"=>"ACTIVE"
      }
    ]
  },
  "user_roles"=>{
    "user_role"=>[
      {
        "status"=>"ACTIVE",
        "scope"=>"01UCS_BER",
        "role_type"=>"200",
        "parameters"=>nil
      },
      {
        "status"=>"ACTIVE",
        "scope"=>"01UCS_BER",
        "role_type"=>"21",
        "parameters"=>{
          "parameter"=>{
            "type"=>"CantEditRestrictedUsers",
            "value"=>"false"
          }
        }
      }
    ]
  },
  "user_blocks"=>nil,
  "user_notes"=>{
    "user_note"=>[
      {
        "segment_type"=>"Internal",
        "note_type"=>"LIBRARY",
        "note_text"=>"Record Source: U",
        "user_viewable"=>"false",
        "popup_note"=>"false",
        "created_by"=>"System",
        "created_date"=>"2020-03-05T10:59:00Z"
      },
      {
        "segment_type"=>"Internal",
        "note_type"=>"LIBRARY",
        "note_text"=>"Total Checkout: 0",
        "user_viewable"=>"false",
        "popup_note"=>"false",
        "created_by"=>"System",
        "created_date"=>"2020-03-05T10:59:00Z"
      },
      {
        "segment_type"=>"Internal",
        "note_type"=>"LIBRARY",
        "note_text"=>"Current Checkout: 0",
        "user_viewable"=>"false",
        "popup_note"=>"false",
        "created_by"=>"System",
        "created_date"=>"2020-03-05T10:59:00Z"
      },
      {
        "segment_type"=>"Internal",
        "note_type"=>"LIBRARY",
        "note_text"=>"Claims Returned: 0",
        "user_viewable"=>"false",
        "popup_note"=>"false",
        "created_by"=>"System",
        "created_date"=>"2020-03-05T10:59:00Z"
      },
      {
        "segment_type"=>"Internal",
        "note_type"=>"LIBRARY",
        "note_text"=>"Updated Date: 07-21-2021",
        "user_viewable"=>"false",
        "popup_note"=>"false",
        "created_by"=>"System",
        "created_date"=>"2020-03-05T10:59:00Z"
      },
      {
        "segment_type"=>"Internal",
        "note_type"=>"LIBRARY",
        "note_text"=>"Message Note: -",
        "user_viewable"=>"false",
        "popup_note"=>"false",
        "created_by"=>"System",
        "created_date"=>"2020-03-05T10:59:00Z"
      },
      {
        "segment_type"=>"Internal",
        "note_type"=>"LIBRARY",
        "note_text"=>"20211019 library book scan eligible [litscript]",
        "user_viewable"=>"false",
        "popup_note"=>"false",
        "created_by"=>"Framework",
        "created_date"=>"2021-10-19T04:38:00Z"
      },
      {
        "segment_type"=>"Internal",
        "note_type"=>"LIBRARY",
        "note_text"=>"20211027 Doe/Moffitt study room eligible [litscript]",
        "user_viewable"=>"false",
        "popup_note"=>"false",
        "created_by"=>"Framework",
        "created_date"=>"2021-10-27T21:59:00Z"
      }
    ]
  },
  "user_statistics"=>{
    "user_statistic"=>[
      {
        "segment_type"=>"External",
        "statistic_category"=>"UCB"
      },
      {
        "segment_type"=>"External",
        "statistic_category"=>"LibrStaff"
      },
      {
        "segment_type"=>"External",
        "statistic_category"=>"SACP"
      }
    ]
  },
  "proxy_for_users"=>nil
}