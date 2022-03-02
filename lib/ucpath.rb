# frozen_string_literal: true

require_relative 'ucpath/api'
require_relative 'ucpath/user'

# UCPath exporter
module UCPath
  VERSION = '1.0'
  include UCPath::API
  # include UCPath::User
end
