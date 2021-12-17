require 'faraday'

module UCPath
  module API

    def fetch_user_by_id(id)
      req = url_root + "employees/#{id}?id-type=hr-employee-id"

      res = fetch(req)

      # TODO - handle errors!
      return nil unless res.status == 200

      # No error... let's parse our response and continue:
      # response = JSON.parse(res.body)
      response = res.body
    end
    
    def fetch_jobs_by_id(id)
      req = url_root + "employees/#{id}/jobs?id-type=hr-employee-id"

      res = fetch(req)

      # TODO - handle errors!
      return nil unless res.status == 200

      # No error... let's parse our response and continue:
      # If we want to switch to JSON (might be easier to deal with)
      # then we can parse it like so:
      #response = JSON.parse(res.body)
      response = res.body
    end

    def change_log(change_from, change_to)
      # where we'll stash our IDs:
      user_ids = []

      # Define the number of records to fetch per request:
      page_size = "&page-size=5"

      # Define a variable to track our current page:
      current_page = 0

      # Define our last page initially (we'll set it after our first fetch)
      # last_page = 3
      

      # Start to loop through the data:
      loop do
        # Add 1 to our current page:
        current_page += 1

        # Create our query parameter:
        page_number = "&page-number=#{current_page}"

        # Tell me what the fuck we're doing!
        puts "Fetching Page --> #{current_page}"
        
        # Generate our request:
        req = url_root + "employees?change-from=#{change_from}&change-to=#{change_to}"
        
        # Add size and pagination
        req = req + page_size + page_number

        # Tell me the request we're making....
        puts "request : #{req}"

        res = fetch(req, 'json')

        # If it failed then return
        # TODO - make handle errors!
        return nil unless res.status == 200
        
        # No error... let's parse our response and continue:
        response = JSON.parse(res.body)
        
        return nil if response.blank?
        puts "---------- API | line# 87 ------------"
        puts "response : #{response}"
        puts "--------------------------------------"
        
        # Put the offset into a var for easy peasy access:
        offset = response['offset']

        # Keep user posted on where we are at with grabbing data:
        puts "REMAINING: #{offset['remaining']}"

        # Put the Users IDs from the response into a variable:
        identifiers = response['response']
        
        # Grab the "hr-employee-id" from this batch:
        identifiers.each do |i|
          i['identifiers'].each_with_index do |identifier, idx|
            if identifier['type'] == 'hr-employee-id'
              user_ids.push(identifier['id'])
              break
            end
          end
        end

        # Check the offset to see if we should continue or break:
        break loop if offset['remaining'] <= 0
      end
      
      # Return the user ids:
      user_ids
    end

    private

    def url_root
      Config.secrets.ucpath.root
    end

    def ucpath_key
      Config.secrets.ucpath.key
    end

    def ucpath_id
      Config.secrets.ucpath.id
    end

    def fetch(req, type = 'xml')
      res = Faraday.get(
        req,
        {},
        {
          'Accept'  => "application/#{type}",
          'app_id'  => ucpath_id,
          'app_key' => ucpath_key
        }
      )

      res
    end

  end
end
