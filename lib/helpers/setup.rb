# Mainly wrangles the command line args: type, dates, etc...
require 'date'
require 'pathname'
require 'getoptlong'

module Helpers
  class Setup
    # Command Line Args:
    attr_reader :type, :users, :start_date, :end_date, :num_days, :term_id, :outdir

    # File Names
    attr_reader :xml_path, :zip_path

    def initialize
      wrangle_commandline
      set_dates
      set_filenames
    end

    def set_filenames
      # If no outdir define it as empty string
      @outdir ||= Dir.pwd

      # range
      range = "#{start_date}-#{end_date}"

      # If we passed users at the CL change range to adhock
      range = 'adhoc' if users

      # Define our filename base
      fn_base = "#{type}_#{range}"

      # Define the xml and zip file paths
      root_path = Pathname.new(@outdir)
      @xml_path = root_path + "#{fn_base}.xml"
      @zip_path = root_path + "#{fn_base}.zip"
    end

    def set_dates
      # Default end date is 'yesterday'
      @end_date ||= Date.today - 1

      # Default start date is the
      @start_date ||= end_date - Config.setting('change_log_days')
    end

    # rubocop :disable Metrics/CyclomaticComplexity, Metrics/MethodLength
    def wrangle_commandline
      opts = GetoptLong.new(
        ['--help', '-h', GetoptLong::NO_ARGUMENT],
        ['--type', '-t', GetoptLong::REQUIRED_ARGUMENT],
        ['--startdate', '-s', GetoptLong::REQUIRED_ARGUMENT],
        ['--enddate', '-e', GetoptLong::REQUIRED_ARGUMENT],
        ['--users', '-u', GetoptLong::REQUIRED_ARGUMENT],
        ['--term', GetoptLong::REQUIRED_ARGUMENT],
        ['--outdir', '-o', GetoptLong::REQUIRED_ARGUMENT]
      )

      opts.each do |opt, arg|
        case opt
        when '--help'
          puts Config.help
          exit
        when '--type'
          @type = arg
        when '--startdate'
          @start_date = arg
        when '--enddate'
          @end_date = arg
        when '--users'
          @users = arg.split(/\s*,\s*/)
        when '--term'
          @term_id = arg
        when '--outdir'
          @outdir = arg
        end
      end
    end
    # rubocop :enable Metrics/CyclomaticComplexity, Metrics/MethodLength
  end
end
