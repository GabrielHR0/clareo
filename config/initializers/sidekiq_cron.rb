unless defined?(Rails) && Rails.env.test?
  if defined?(Sidekiq)
    begin
      require 'sidekiq/cron/job'

      schedule = {
        'credit_repayment_worker' => {
          'class' => 'CreditRepaymentWorker',
          'cron' => '*/5 * * * *',
          'description' => 'Apply pending donations to credit lines every 5 minutes'
        },
        'recurring_charge_worker' => {
          'class' => 'RecurringChargeWorker',
          'cron' => '0 2 * * *',
          'description' => 'Process recurring donations daily at 02:00'
        }
      }

      schedule.each do |name, job|
        Sidekiq::Cron::Job.create(name: name, cron: job['cron'], class: job['class'], description: job['description'])
      end
    rescue LoadError => e
      Rails.logger.info("sidekiq-cron not available: #{e.message}")
    end
  end
end
