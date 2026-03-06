# frozen_string_literal: true

require 'erb'
require 'yaml'
require 'json'
require 'logger'
require_relative '../lib/docker'

# NOTE: dotenv/load must come after ../lib/docker
require 'dotenv/load'

# Config class to hold/manage our configuration
class Config
  # Define your Structs for Secrets:
  Ucpath = Struct.new(:root, :id, :key, keyword_init: true)
  Sis = Struct.new(:root, :id, :key, keyword_init: true)
  Ldap = Struct.new(:host, :pass, keyword_init: true)
  Secrets = Struct.new(:ucpath, :sis, :ldap, keyword_init: true)

  class << self
    attr_reader :secrets, :settings, :help

    def load!
      # Load the ENV vars
      Docker::Secret.setup_environment!

      load_settings!('config/settings.yml')
      load_secrets!('config/secrets.yml')
    end

    # Returns specified field value from settings.yml
    def setting(field)
      @settings[field.to_sym]
    end

    def ucpath_employee_fields
      @ucpath_fields['employee']['fields']
    end

    def sis_fields
      @sis_fields['SIS']['fields']
    end

    def ucpath_job_fields
      @ucpath_fields['job']['fields']
    end

    def student_affiated?(affiliation)
      @ldap_fields['student_affiliation'].include? affiliation
    end

    def ldap_attributes
      @ldap_fields['attributes']
    end

    def check_ucpath_code(type, value)
      @ucpath_codes[type].include? value
    end

    private

    def load_settings!(path)
      raw = yaml_with_erb(path)

      # Load those config settings from the yaml hash:
      @settings = create_struct_from_hash(
        name: 'Settings',
        hash: raw.fetch('settings')
      )

      # keep help separate...it's just a string
      @help = raw['help']
    end

    def load_secrets!(path)
      raw = yaml_with_erb(path)

      @secrets = Secrets.new(
        ucpath: Ucpath.new(**symbolize(raw.fetch('ucpath'))),
        sis: Sis.new(**symbolize(raw.fetch('sis'))),
        ldap: Ldap.new(**symbolize(raw.fetch('ldap')))
      )

      # Over-ride the LDAP host if we're in CI land... JUST to make
      # sure we don't hit the actual host when we're running rspec!
      @secrets.ldap.host = 'ldap.fake.edu' if ENV['CI']
    end

    def symbolize(hash)
      hash.transform_keys(&:to_sym)
    end

    def yaml_with_erb(path)
      YAML.safe_load(ERB.new(File.read(path)).result)
    end

    # Since settings isn't nested hash of hashes easy enough to create this struct dynamically:
    def create_struct_from_hash(name:, hash:)
      # Since Structs need symbols....
      sym_hash = hash.transform_keys(&:to_sym)

      struct_class = if const_defined?(name, false)
                       const_get(name)
                     else
                       const_set(name, Struct.new(*sym_hash.keys, keyword_init: true))
                     end

      struct_class.new(**sym_hash)
    end
  end

  # Let's do this!!!!
  load!

  ucpath_contents = File.read('config/ucpath_fields.yml')
  @ucpath_fields = YAML.safe_load(ERB.new(ucpath_contents).result)

  ldap_contents = File.read('config/ldap_fields.yml')
  @ldap_fields = YAML.safe_load(ERB.new(ldap_contents).result)

  ucpath_codes = File.read('config/ucpath_codes.yml')
  @ucpath_codes = YAML.safe_load(ERB.new(ucpath_codes).result)

  sis_contents = File.read('config/sis_fields.yml')
  @sis_fields = YAML.safe_load(ERB.new(sis_contents).result)
end
