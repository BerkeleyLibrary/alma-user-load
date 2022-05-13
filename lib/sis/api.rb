require 'faraday'

module SIS
  # SIS API module
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
      prefix = Date.today.year.to_s

      # Remove that digit!
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

    # Fetch term by ID - can include as_of_date filter changes by a date
    # which requires 2 passes. (Takes a loooong time!)
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/BlockLength
    def fetch_by_term(term_id, as_of_date = nil)
      mode = as_of_date.nil? ? 'Current' : 'Past'

      raw_users = []

      logger.info "Fetching #{mode} Data..."

      current_page = 0

      loop do
        current_page += 1

        # break loop if current_page > 5

        logger.info "  Page: #{current_page}"

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

        # Max page size is 100
        # though API doesn't really stick to it
        req += '&page-size=100'

        # We'll need to page through the results
        req += "&page-number=#{current_page}"

        # If we want to run a snapshot for a previous timeframe:
        req += "&as-of-date=#{as_of_date}" if as_of_date

        # https://apis.berkeley.edu/sis/v2/students?term-id=2222&inc-cntc=true&inc-regs=true&page-size=100&page-number=1&as-of-date=2022-02-16
        # Fetch it!
        res = sis_fetch(req, 'json')

        break loop unless res && res.status == 200

        response = JSON.parse(res.body)

        # return nil if !response || response == ''
        # return nil unless res.status == 200

        status = response['apiResponse']['httpStatus']['code']

        break loop if status != '200'

        # Remove after dev:
        # break loop if raw_users.count > 2

        # Extract the students array from the response
        students = response['apiResponse']['response']['students'] || 0

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
          end

          raw_users.push(s)
        end
      end

      raw_users
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/BlockLength

    private

    def sis_root
      Config.secrets.sis.root
    end

    def sis_key
      Config.secrets.sis.key
    end

    def sis_id
      Config.secrets.sis.id
    end

    # rubocop :disable Metrics/MethodLength
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
        logger.error "SIS API Error: #{e}"
        logger.error "Attempt: #{attempts}"
        logger.error "Request: #{req}"
        retry if attempts <= 7

        nil
      end
    end
    # rubocop :enable Metrics/MethodLength
  end
end
