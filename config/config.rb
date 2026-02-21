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

  ucpath_contents = File.read('config/ucpath_fields.yml')
  @ucpath_fields = YAML.safe_load(ERB.new(ucpath_contents).result)

  ldap_contents = File.read('config/ldap_fields.yml')
  @ldap_fields = YAML.safe_load(ERB.new(ldap_contents).result)

  ucpath_codes = File.read('config/ucpath_codes.yml')
  @ucpath_codes = YAML.safe_load(ERB.new(ucpath_codes).result)

  sis_contents = File.read('config/sis_fields.yml')
  @sis_fields = YAML.safe_load(ERB.new(sis_contents).result)

  # Over-ride the LDAP host if we're in CI land... JUST to make
  # sure we don't hit the actual host when we're running rspec!
  @secrets.ldap.host = 'ldap.fake.edu' if ENV['CI']

  # Returns ostruct of the secrets yaml file
  class << self
    attr_reader :secrets
  end

  def self.ucpath_employee_fields
    @ucpath_fields['employee']['fields']
  end

  def self.sis_fields
    @sis_fields['SIS']['fields']
  end

  def self.ucpath_job_fields
    @ucpath_fields['job']['fields']
  end

  def self.student_affiated?(affiliation)
    @ldap_fields['student_affiliation'].include? affiliation
  end

  def self.check_ucpath_code(type, value)
    @ucpath_codes[type].include? value
  end

  # Returns specified field value from settings.yml
  def self.setting(field)
    @settings.settings[field] || nil
  end

  def self.help
    @settings.help
  end
end
