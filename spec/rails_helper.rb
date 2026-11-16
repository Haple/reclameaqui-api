require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
ENV["CLOUDFLARE_ACCOUNT_ID"] = "test-account"
ENV["CLOUDFLARE_API_TOKEN"] = "test-token"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "webmock/rspec"

Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |file| require file }

RSpec.configure do |config|
  config.use_active_record = false
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include FixtureHelpers
  config.include BrowserRenderingHelpers
  config.include SignInHelpers, type: :request
  config.include ActiveSupport::Testing::TimeHelpers

  config.before do
    Mongoid.purge!
    ActionMailer::Base.deliveries.clear
  end
end
