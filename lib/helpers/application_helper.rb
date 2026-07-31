require 'date'

module Helpers
  module ApplicationHelper

    def upcath_expire_date(group, expdate = nil)
      # If we don't have an expire date return our default
      return create_expected_end_date if expdate.empty?

      # If faculty then make sure their expdate isn't in the "safe zone" (see below)
      return "#{Date.today.year}-09-01" if group == 'FACULTY' && faculty_safe_zone?(expdate)

      expdate
    end

    def sis_expire_date(active_student)
      return create_expected_end_date if [5, 8, 12].include? Date.today.month
      return Date.today.to_s if active_student == false

      create_expected_end_date
    end

    private

    #----------------------------------------------------------------#
    # Per Dave Rez:                                                  #
    # Faculty apparently hate getting cut off from the library       #
    # around this time of year. To minimize that possibility,        #
    # we'll delay expiry date to Sep01 if the expire date            #
    # their job lists is between May 15th and June 30th              #
    #----------------------------------------------------------------#
    def faculty_safe_zone?(date)
      expire_date = Date.parse(date)
      start_date = Date.parse("#{Date.today.year}-05-15")
      end_date = Date.parse("#{Date.today.year}-06-30")

      expire_date.between?(start_date, end_date)
    end

    #----------------------------------------------------------------#
    # Per Alvin:                                                     #
    # Date advances forward expiration_year_interval years on the    #
    # first day of change_month.                                     #
    # For example on July 31 2009 the expiration date will be        #
    # 10-31-2010. On Aug 1 2009 though, the expiration date will     #
    # advance forward two years to 10-31-2011.                       #
    #----------------------------------------------------------------#
    def create_expected_end_date
      expiration_month_day = '10-31'
      expiration_year_interval = 2
      change_month = 7

      d = Date.today

      expiration_year = if d.month < change_month
                          d.year + expiration_year_interval - 1
                        else
                          d.year + expiration_year_interval
                        end

      "#{expiration_year}-#{expiration_month_day}"
    end

  end
end
