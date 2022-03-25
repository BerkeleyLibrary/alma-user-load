# frozen_string_literal: true

require 'erb'
require 'yaml'
require 'json'
require 'logger'
require 'ostruct'
require_relative '../lib/docker'

# NOTE: dotenv/load must come after ../lib/docker
require 'dotenv/load'
# I think I need to only call this if we're NOT running in a container:
# require 'dotenv/load' unless Docker.running_in_container?

# Config class to hold/manage our configuration
class Config
  # Load the ENV vars
  Docker::Secret.setup_environment!

  # Secrets (passwords, api keys, etc...): Uses ERB for ENV variables
  @secrets = JSON.parse(YAML.safe_load(ERB.new(File.read('config/secrets.yml')).result).to_json,
                        object_class: OpenStruct)

  # General Settings: Uses ERB for ENV variables
  @settings = JSON.parse(YAML.safe_load(ERB.new(File.read('config/settings.yml')).result).to_json,
                         object_class: OpenStruct)

  ucpath_contents = File.open('config/ucpath_fields.yml').read
  @ucpath_fields = YAML.safe_load(ERB.new(ucpath_contents).result)

  ldap_contents = File.open('config/ldap_fields.yml').read
  @ldap_fields = YAML.safe_load(ERB.new(ldap_contents).result)

  ucpath_codes = File.open('config/ucpath_codes.yml').read
  @ucpath_codes = YAML.safe_load(ERB.new(ucpath_codes).result)

  sis_contents = File.open('config/sis_fields.yml').read
  @sis_fields = YAML.safe_load(ERB.new(sis_contents).result)

  # Returns ostruct of the secrets yaml file
  class << self
    attr_reader :secrets
  end

  # Returns ostruct of settings yaml file
  # def self.settings
  #   @settings
  # end

  # def self.load_secrets!
  #   @secrets = JSON.parse(YAML.safe_load(ERB.new(File.read('config/secrets.yml')).result).to_json,
  #     object_class: OpenStruct)
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
