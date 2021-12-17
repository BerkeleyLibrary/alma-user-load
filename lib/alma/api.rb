require 'faraday'

module Alma
  ALMA_API_URL = Config.secrets.alma.url
  ALMA_API_KEY = Config.secrets.alma.key
  
  module API
    def fetch_alma_user(id)
      req = "#{ALMA_API_URL}users/#{id}?view=full&expand=none&apikey=#{ALMA_API_KEY}"
      res = Faraday.get(req, {}, 'Accept' => 'application/json')
      
      puts "\n\nERROR: Alma query failed with response: #{res.status}" unless res.status == 200
      res
    end
  end
end


# module AlmaServices
#   class Patron

#     def self.authenticate_alma_patron(alma_id, alma_password)
#       req = "#{Config.alma_api_url}users/#{alma_id}?op=auth&password=#{alma_password}&view=full&apikey=#{Config.alma_api_key}"
#       res = Faraday.post(req, {}, 'Accept' => 'application/json')
#       res.success?
#     end

#     # expand=fees is added since the default response is nil for fees
#     def self.get_user(alma_id)
#       req = "#{Config.alma_api_url}users/#{alma_id}?view=full&expand=fees&apikey=#{Config.alma_api_key}"
#       res = Faraday.get(req, {}, 'Accept' => 'application/json')
#       raise ActiveRecord::RecordNotFound, "Alma query failed with response: #{res.status}" unless res.status == 200

#       res
#     end

#     def self.valid_proxy_patron?(alma_id)
#       res = get_user(alma_id)
#       ValidProxyPatron.valid?(JSON.parse(res.body))
#     end

#     def self.save(alma_id, user)
#       req = "#{Config.alma_api_url}users/#{alma_id}?apikey=#{Config.alma_api_key}"
#       res = Faraday.put(req, user.to_json, { 'Content-Type' => 'application/json', 'Accept' => 'application/json' })
#       raise ActiveRecord::RecordNotFound, 'Failed to save.' unless res.status == 200

#       'Saved user.'
#     end

#   end

#   class Fines
#     def self.fetch_all(alma_user_id)
#       req = "#{Config.alma_api_url}users/#{alma_user_id}/fees?apikey=#{Config.alma_api_key}"
#       res = Faraday.get(req, {}, 'Accept' => 'application/json')
#       raise ActiveRecord::RecordNotFound, 'No fees could be found.' unless res.status == 200

#       JSON.parse(res.body)
#     end

#     def self.credit(alma_user_id, pp_ref_number, fine)
#       # If you pay the full amount owed for a fee, it automatically changes the status to "CLOSED"
#       req = "#{Config.alma_api_url}users/#{alma_user_id}/fees/#{fine.id}?apikey=#{Config.alma_api_key}&op=pay&amount=#{fine.balance}
#       &method=ONLINE&external_transaction_id=#{pp_ref_number}"

#       res = Faraday.post(req, {}, 'Accept' => 'application/json')
#       raise ActiveRecord::RecordNotFound, "Failed to credit fee #{fee_id}" unless res.status == 200
#     end
#   end

#   class Config
#     def self.alma_api_url
#       Rails.application.config.alma_api_url
#     end

#     def self.alma_api_key
#       Rails.application.config.alma_api_key
#     end
#   end

# end
