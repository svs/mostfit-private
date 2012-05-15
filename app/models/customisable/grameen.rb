module Foremost
  module Grameen
    module Loan
      def stub_dates
        dd = self.disbursal_date || self.scheduled_disbursal_date
        self.center.slice(dd, self.scheduled_first_payment_date) - [self.scheduled_first_payment_date]
      end
    end
  end
end
