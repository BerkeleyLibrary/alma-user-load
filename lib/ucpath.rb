require_relative 'ucpath/api'
require_relative 'ucpath/user'

module UCPath
  VERSION = '1.0'
  include UCPath::API
  #include UCPath::User
end