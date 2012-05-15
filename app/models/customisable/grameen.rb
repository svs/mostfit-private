module Foremost
  module Grameen
    module Loan

      def _stub_dates
        dd = self.disbursal_date || self.scheduled_disbursal_date
        self.center.slice(dd, self.scheduled_first_payment_date) - [self.scheduled_first_payment_date]
      end

      # Returns a list if dates between the disbursal date and the scheduled first payment date that would have been 
      # installment dates
      def stub_dates
        eds = []; d = scheduled_first_payment_date
        while d >= (disbursal_date || scheduled_disbursal_date)
          d = shift_date_by_installments(d, -1, false)
          eds << d if d >= (disbursal_date || scheduled_disbursal_date)
        end
        eds
      end

      def calculate_stub_interest_payments
        d1 = disbursal_date || scheduled_disbursal_date
        interest_so_far = 0
        stub_dates.each do |d2|
          interest = interest_calculation(amount, d1, d2)
          @schedule[d2] = {
            :principal                  => 0,
            :interest                   => interest,
            :fees                       => 0,
            :total_principal            => 0,
            :total_interest             => interest_so_far + interest,
            :total                      => interest_so_far.round(2),
            :balance                    => amount.round(2),
          }
          d1 = d2
        end
      end


      
      
      
      # Actually, this methid has no business being here. It is here to support stub period calculation. The correct answer is to beef up
      # our Thermostat gem to generate schedules that go backwards
      # in the meantime, welcome to the suck!

      def shift_date_by_installments(date, number, ensure_meeting_day = true)
        return date if number == 0
        case self.installment_frequency
        when :daily
          new_date =  date + number
        when :weekly
          new_date =  date + number * 7
        when :biweekly
          new_date = date + number * 14
        when :quadweekly
          new_date = date + number * 28
        when :monthly
          new_date = date >> number
        else
          raise ArgumentError.new("Strange period you got..")
        end
        new_date
      end
    end
  end
end
