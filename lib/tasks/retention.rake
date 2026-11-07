namespace :retention do
  desc "Delete data past its retention period"
  task purge: :environment do
    puts Retention.purge!.inspect
  end
end
