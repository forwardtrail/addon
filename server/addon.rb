######
# Addon Server for processing webhooks (Sinatra)
# feel free to edit this file, however you shouldn't need to
# add your webhook event handling code in `event.rb`
######

require "sinatra"
require "active_support/all"
require "openssl"
require "yaml"
require "oj"

require_relative "./event"

configure do
  enable :logging

  set :hmac_algorithm, OpenSSL::Digest.new('sha1')

  # set secret
  addon_settings = YAML.load_file(File.expand_path("../addon.yml", File.dirname(__FILE__)))
  set :secret, addon_settings["secret"]
end

get "/" do
  "A ForwardTrail.com Addon..."
end

# handles ForwardTrail webhooks POST data (bulk)
#
# - validates the request came from ForwardTrail.com (via the shared secret)
# - process the bulk events posts and creates an `Event` for each one
# - runs `process!` on each event
#
post "/" do
  content_type :json

  request.body.rewind
  payload_body = request.body.read

  signature = OpenSSL::HMAC.hexdigest(settings.hmac_algorithm, settings.secret, payload_body) if payload_body.present?

  if payload_body.present? and request.env["HTTP_X_FT_SIGNATURE"].present? and Rack::Utils.secure_compare(request.env["HTTP_X_FT_SIGNATURE"], signature)
    data = Oj.load(payload_body)

    accounts = data["accounts"]
    Array.wrap(data["events"]).each do |event|
      account = accounts.detect{|a| a["id"] == event["account_id"]}
      Event.new(account: account, event: event).process!
    end
    {"success" => true}.to_json
  elsif payload_body.blank?
    {"success" => false, "message" => "No body."}.to_json
  else
    {"success" => false, "message" => "Signature does not match."}.to_json
  end

end