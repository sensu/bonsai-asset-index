web: bundle exec puma -C config/puma.rb
release: rake db:migrate
worker: bundle exec sidekiq -C config/sidekiq.yml 