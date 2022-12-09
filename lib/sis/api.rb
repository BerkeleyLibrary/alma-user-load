require 'faraday'

module SIS
  # SIS API module

  # rubocop:disable Metrics/ModuleLength
  module API

    #----------------------------------------------------------------#
    # Term Codes:
    # From Dave Rez: They have the most confusing term ids. The
    # current term is "2222." This (below) is the commented note I
    # put in my query to help me remember, the thing to know is that
    # the second character of the year is dropped, so 2022 becomes
    # 222, the last character is the code for whichever term it is,
    # fall, spring or summer.
    # 2178 = fall semester for 2017
    # 8=Fall
    # 2=Spring
    # 5=Summer
    #----------------------------------------------------------------#
    def current_term
      # Prefix is the year, minus the 2nd digit (WEIRD!)
      prefix = Date.today.year.to_i

      # Remember - if it's December and we're
      prefix += 1 if Date.today.month == 12

      # Remove that digit!
      prefix = prefix.to_s
      prefix.slice!(1, 1)

      # Return the prefix plus the term code for Fall||Spring||Summer
      "#{prefix}#{term_code}"
    end

    def term_code
      case Date.today.month
      when 12, 1, 2, 3, 4
        # Spring
        '2'
      when 5, 6, 7
        # Summer
        '5'
      else
        # Fall
        '8'
      end
    end

    # Because we change term at the beginning of the month (or in the case of December
    # the beginning of the prior month) of when the new term actually begins we have
    # to set an "as-of-date" in the query string beyond the term start date. Here I
    # set the start date to the last day of the month where the new term begins:
    # Example:
    # Spring 2023 term offical start date is January 10th - so I
    # set to January 31st
    def as_of_date
      case Date.today.month
      when 12
        # We need to set an as-of-date of January 31st of the FOLLOWING year
        # Have to do this because the spring term starts the next year.
        "#{Date.today.year + 1}-01-31"
      when 1
        # We need to set an as-of-date of January 31st of the current year
        "#{Date.today.year}-01-31"
      when 5
        # We need to set an as-of-date of May 31st of the current year
        "#{Date.today.year}-05-31"
      when 8
        # We need to set an as-of-date of August 31st of the current year
        "#{Date.today.year}-08-31"
      end

      # Otherwise we return nil
    end

    # Fetch term by ID - can include as_of_date filter changes by a date
    # which requires 2 passes. (Takes a loooong time!)
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/BlockLength
    def fetch_by_term(term_id, as_of_date = nil)
      raw_users = []

      current_page = 0

      loop do
        current_page += 1

        logger.info "  Page: #{current_page}"

        req = create_request(term_id, current_page, as_of_date)

        res = ''
        response = ''

        # Now that SIS fixed their jenky 
        (1..5).each do |i|
          logger.info "    attempt: #{i}"

          res = sis_fetch(req, 'json')

          next unless res && res.status == 200

          response = parse_body(res)

          # Need to break out of this 1..5 loop if we got a full response
          break if response

          sleep 2
        end

        break loop unless res && res.status == 200

        status = response['apiResponse']['httpStatus']['code']

        break loop if status != '200'

        # Extract the students array from the response
        students = response['apiResponse']['response']['students'] || 0

        errors = false

        students.each_with_index do |student, _idx|
          # Bundle this student's data into a hash
          s = {}

          # sis_fields.yml contains the SIS fields we want to
          # collect and then store in our hash
          Config.sis_fields.each do |f|
            name = f['name']
            jpath = f['jpath']
            status = f['status'] || 'OPTIONAL'

            next unless jpath

            s[name] = JsonPath.on(student, jpath).first || ''

            if status == 'REQUIRED' && (!s[name] || s[name] == '')
              logger.error "#{s['student_id']} - missing required field: #{name}"
              errors = true
            end
          end

          raw_users.push(s) unless errors
        end
      end

      raw_users
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/BlockLength

    private

    def create_request(term_id, current_page, as_of_date)
      # Build our API Request:
      req = sis_root

      # Add the current term
      req += "?term-id=#{term_id}"

      # Include Contact Info
      req += '&inc-cntc=true'

      # Include Registration Info
      req += '&inc-regs=true'

      # Include Academic Info
      req += '&inc-acad=true'

      # Make sure we get all users regardless of affiliation-status
      req += '&affiliation-status=ALL'

      # Max page size is 100 - though API doesn't really stick to it
      req += '&page-size=50'

      # We'll need to page through the results
      req += "&page-number=#{current_page}"

      # If we want to run a snapshot for a previous timeframe:
      req += "&as-of-date=#{as_of_date}" if as_of_date

      req
    end

    def parse_body(res)
      JSON.parse(res.body)
    rescue JSON::ParserError => e
      # return false if we run into a JSON parsing error
      logger.error "JSON PARSING ERROR: #{e}"
      logger.error "Response headers: #{res.headers.inspect}"
      logger.error "Body length: #{res.body.length}"
      false
    end

    def sis_root
      Config.secrets.sis.root
    end

    def sis_key
      Config.secrets.sis.key
    end

    def sis_id
      Config.secrets.sis.id
    end

    # rubocop :disable Metrics/MethodLength, Metrics/AbcSize
    def sis_fetch(req, type = 'xml')
      # TODO: make #attempts and sleep time config items
      # and over-ridable for testing...
      attempts = 0
      begin
        attempts += 1
        sleep(15) if attempts > 1
        logger.info "Attempt: #{attempts}" if attempts > 1

        Faraday.get(
          req,
          {},
          {
            'Accept' => "application/#{type}",
            'app_id' => sis_id,
            'app_key' => sis_key
          }
        )
      rescue StandardError => e
        attempts += 1
        logger.info "API Error(#{attempts}): #{e}"
        logger.info "Request: #{req}"
        retry if attempts <= 7

        # We've exhausted all of our retries - API must be down. Bale.
        logger.error 'FATAL ERROR: Exhausted API rquests'
        logger.error "Fatal API Error: #{e}"

        throw StandardError.new 'API Error'
      end
    end
    # rubocop :enable Metrics/MethodLength, Metrics/AbcSize
  end
  # rubocop:enable Metrics/ModuleLength
end
