# frozen_string_literal: true

require 'faraday'

module UCPath
  # UCPATH API module - fetch employee and job info
  module API
    def fetch_ucpath_rec(id)
      req = url_root + "employees/#{id}?id-type=hr-employee-id"

      res = fetch(req, 'json')

      return nil unless res && res.status == 200

      logger.info "#{id} - Successfully fetched UCPath record"

      res.body
    end

    def fetch_ucpath_jobs(id)
      req = url_root + "employees/#{id}/jobs?id-type=hr-employee-id"

      res = fetch(req, 'json')

      # TODO: - handle errors!
      return nil unless res && res.status == 200

      res.body
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    def change_log(change_from, change_to)
      # where we'll stash our IDs:
      user_ids = []
      logger.info 'Fetching Change Log...'

      # Define the number of records to fetch per request:
      # TODO - move this to config
      page_size = '&page-size=200'

      # Define a variable to track our current page:
      current_page = 0

      # Start to loop through the data:
      loop do
        # Add 1 to our current page:
        current_page += 1

        # break loop if current_page >= 5

        logger.info "Change Log page: #{current_page}"
        # Create our query parameter:
        page_number = "&page-number=#{current_page}"

        # Generate our request:
        req = url_root + "employees?change-from=#{change_from}&change-to=#{change_to}"

        # Add size and pagination
        req = req + page_size + page_number

        res = fetch(req, 'json')

        # If it failed then return
        return nil unless res && res.status == 200

        # If it the API gave us an empty body return
        return nil if res.body.empty?

        # No error... let's parse our response and continue:
        response = JSON.parse(res.body)

        return nil if !response || response == ''

        # Put the offset into a var for easy peasy access:
        offset = response['offset']

        # Keep user posted on where we are at with grabbing data:
        # puts "REMAINING: #{offset['remaining']}"

        # Put the Users IDs from the response into a variable:
        identifiers = response['response']

        # Grab the "hr-employee-id" from this batch:
        identifiers.each do |i|
          i['identifiers'].each_with_index do |identifier, _idx|
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
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

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

    # rubocop:disable Metrics/MethodLength
    def fetch(req, type = 'xml')
      attempts = 0
      begin
        attempts += 1
        sleep(5) if attempts > 1
        logger.info "Attempt: #{attempts}" if attempts > 1

        Faraday.get(
          req,
          {},
          {
            'Accept' => "application/#{type}",
            'app_id' => ucpath_id,
            'app_key' => ucpath_key
          }
        )
      rescue StandardError => e
        attempts += 1
        logger.error "UCPath API Error: #{e}"
        logger.error "Attempt: #{attempts}"
        logger.error "Request: #{req}"
        retry if attempts <= 3

        nil
      end
    end
    # rubocop:enable Metrics/MethodLength
  end
end
