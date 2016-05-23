IlluminaCPipeline::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the webserver when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_view.debug_rjs             = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  config.api_connection_options               = ActiveSupport::OrderedOptions.new
  config.api_connection_options.namespace     = 'IlluminaC'
  config.api_connection_options.url           = ENV.fetch('API_URL','http://localhost:3000/api/1/')
  config.api_connection_options.authorisation = ENV.fetch('AUTHORISATION_TOKEN','development')

  config.details_root = ENV.fetch('DETAILS_ROOT','http://localhost:3000/uuids/')
  config.summary_root = ENV.fetch('SUMMARY_ROOT','http://localhost:3000/plate_summaries/')


  # Email settings...
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = false

  config.action_mailer.delivery_method = :test
  config.action_mailer.smtp_settings = { }

  config.admin_email          = "nnnnnnnnnnnnnnnn"
  config.exception_recipients = "nnnnnnnnnnnnnnnn"


  config.qc_submission_name = "MiSeq for QC"
  # By default used first study/project
  # config.study_uuid = ""
  # config.project_uuid = ""
  config.request_options = {
    "read_length" => 25,
    "fragment_size_required" => {
      "from" => 100,
      "to"   => 100
    }
  }

end

