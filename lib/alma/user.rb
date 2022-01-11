require 'json'

module Alma
  class User
    include Alma::API
    attr_accessor :user
    
    def initialize
      @user = {}
    end

    def load_user(id)
      u = nil
      
      body = Alma::API.fetch_alma_user(id).body
      u = JSON.parse(body, object_class: OpenStruct) if body

      self.user = u
    end
  end
end
