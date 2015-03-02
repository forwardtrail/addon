######
# Addon Server for processing webhooks (Sinatra)
# feel free to edit this file, however you shouldn't need to
# add your webhook event handling code in `event.rb`
######

require "sinatra"
require "active_support/all"
require "openssl"
require "yaml"
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

  data = params[:data].to_s

  if data.present?
    signature = OpenSSL::HMAC.hexdigest(settings.hmac_algorithm, settings.secret, data)

    data = OJ.load(params[:data])
    if data["signature"] == signature
      account = data["account"]
      addon = data["addon"]
      Array.wrap(data["events"]).each do |event|
        Event.new(account: account, addon: addon, event: event).process!
      end
      {"success" => true}.to_json
    else
      {"success" => false, "message" => "Signature does not match."}.to_json
    end

  else
    {"success" => false, "message" => "No Body"}.to_json
  end
end