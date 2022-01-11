require_relative 'alma/api'
require_relative 'alma/user'
require_relative 'alma/xml_builder'

module Alma
  VERSION = '1.0'
  ROOT = File.dirname __dir__

  # Because api.rb is a module you need to include it...
  include Alma::API
  
  # TODO - remove this...probably
  def test
    puts "---------->ALMA TEST..."

    # u = Alma::API.fetch_user('10335026')
    # puts "---------- alma | line# 12 ------------"
    # puts "u.inspect : #{u.inspect}"
    # puts "--------------------------------------"
  end
end