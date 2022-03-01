require 'erb'
require 'yaml'
require 'json'
require 'logger'
require 'ostruct'
require 'dotenv/load'

class Config
  # Secrets (passwords, api keys, etc...): Uses ERB for ENV variables
  @secrets = JSON.parse(YAML.load(ERB.new(File.read('config/secrets.yml')).result).to_json, object_class: OpenStruct)

  # General Settings: Uses ERB for ENV variables
  @settings = JSON.parse(YAML.load(ERB.new(File.read('config/settings.yml')).result).to_json, object_class: OpenStruct)

  ucpath_contents = File.open('config/ucpath_fields.yml').read
  @ucpath_fields = YAML.load(ERB.new(ucpath_contents).result)
  
  ldap_contents = File.open('config/ldap_fields.yml').read
  @ldap_fields = YAML.load(ERB.new(ldap_contents).result)
  
  ucpath_codes = File.open('config/ucpath_codes.yml').read
  @ucpath_codes = YAML.load(ERB.new(ucpath_codes).result)
  
  sis_contents = File.open('config/sis_fields.yml').read
  @sis_fields = YAML.load(ERB.new(sis_contents).result)
  
  # TODO:  Add a check to make sure all necessary config settings are set!
  #        warn if we don't have an .env with necessary settings!
  #        Maybe if missing needed .env locally I can offer a command line option
  #        to create a skeleton .env file.

  # Returns ostruct of the secrets yaml file
  class << self
    attr_reader :secrets
  end

  # Returns ostruct of settings yaml file
  # def self.settings
  #   @settings
  # end

  def self.ucpath_employee_fields
    @ucpath_fields['Employee']['fields']
  end

  def self.sis_fields
    @sis_fields['SIS']['fields']
  end

  def self.ucpath_job_fields
    @ucpath_fields['Job']['fields']
  end

  # def self.ldap_fields
  #   @ldap_fields
  # end

  def self.student_affiated?(affiliation)
    @ldap_fields['Student Affiliation'].include? affiliation
  end

  # def self.ucpath_codes(type)
  #   @ucpath_codes[type]
  # end

  def self.check_ucpath_code(type, value)
    @ucpath_codes[type].include? value
  end

  # Returns specified field value from settings.yml
  def self.setting(field)
    @settings.Settings[field] || nil
  end

  def self.help
    @settings.Help
  end
end
