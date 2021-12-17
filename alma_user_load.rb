# TODO - 
#  Move Keys/PWs to config and ENV vars
#  Setup DockerFile
#  Setup options
#  Setup LDAP fields
#  Setup user aggregation/merge
#  REFACTOR the living shit out this
#  Setup RSPEC
#  Get code coverage to 100%
#  Rubocop it
#  Setup logging
#  Setup error handling!!!!
#  Get this into Gitlab!!!
#  Setup in pipeline
#  Setup "Eligibility" logic!!!
#  EVENTUALLY - Setup better XML builder/template writer

# STEPS:
#  1 - Get List of Users 
#      (either Change Log or full list if doing a full Sync)
#  2 - Go through list:
#    COLLECT DATA:
#    A - Get UCPath Record
#    B - Get LDAP Record
#    C - Get ALMA Record
#    AGGREGATE:
#    D - Create an Alma User Object
#    E - If Alma rec exists check for differences and merge
#    MUNGE:
#    F - Set roles, handle purges, etc...
#    G - Generate XML Fragment (for individual user record)
#    H - Add fragment to XML Doc (for collection)
#  3 - Save XML file
#  4 - Zip file
#  5 - Send XML file to ??? (where Ex Libris collects files for sync/update)
#      FTP to: upload.lib.berkeley.edu/alma/
#                                           patron_employees
#                                           patron_students
#
#   Allow add-hoc runs (Specific date ranges? Specific user IDs?)


require 'getoptlong'

require_relative 'config/config'
require_relative 'lib/alma'
require_relative 'lib/ldap'
require_relative 'lib/sis'
require_relative 'lib/ucpath'

# Include your modules
include Alma
include LDAP
include UCPath


# TODO - Set up options, build help menu!
opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--type', '-t', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--changelog', GetoptLong::NO_ARGUMENT ],
)

opts.each do |opt, arg|
  case opt
    when '--help'
      puts "\n\nruby alma_user_load.rb -t <sis|ucpath>"
      exit
    when '--type'
      @type = arg
    when '--outfile'
      @outfile = arg
    when '--checklinks'
      @checklinks = true
    when '--nofft'
      # global since this is checked in ohc_to_xml.rb module
      $nofft = true
  end
end

if @type == 'ucpath'
  puts "----->Processing UCPath..."

  change_log = UCPath::User.fetch_change_log

  user_list = []

  xml_root = Alma::XML.new("users")

  if change_log
    change_log.each do |id|
      puts "Fetching ID: #{id}"
      # UCPath::User.fetch_user(id)
      u = UCPath::User.new(id)
      
      
      
      #puts "\n\n---------------------------\n"
      puts u.print
      # u.print_obj
      #user_list.push(u)
      
      
      #user_xml = u.to_xml
      #puts user_xml
      #xml_root.append_element(user_xml)

      exit
    end

    # Now go through each item in the user_list and XML'ify it!

    # user_list[0].print_obj
  else
    # Log this? Error? Should we ALWAYS expect some recs?
    puts "\n\nWARNING - No Records Found\n\n"
  end

  # puts "---------- alma_user_load | line# 72 ------------"
  # puts "xml_root.print : #{xml_root.xml}"
  # puts "--------------------------------------"
  
  # To Print XML File:
  # f = File.open("user_uploads.xml", "w")
  # f.write(xml_root.xml)
  # f.close

elsif @type == 'sis'
  # RUN SIS... well eventually, someday, when those SIS folks get off their butts and give access!
  puts "----->SIS"
  puts "one big todo list at this point!\n\n"
elsif @type == 'alma'
  # Quick and dirty ALMA API Testing
  puts "----->ALMA"
  alma_user = Alma::API.fetch_alma_user('10335026')
  puts "---------- alma_user_load | line# 140 ------------"
  puts "user.inspect : #{alma_user.inspect}"
  puts "--------------------------------------"
elsif @type == 'ldap'
  # Quick and dirty test of LDAP
  puts "\n\n----->TESTING LDAP"
  LDAP::API.fetch_ldap_rec('1707532')
else
  puts "\nERROR: type is required and must be 'sis' or 'ucpath'\n"
  exit
end

if @changelog
  puts "---------->fetching change log..."

end

