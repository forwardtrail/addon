class Event
  def initialize(event)
    @event = event.with_indifferent_access
    @account = @event["account"]
    @settings = @account["addon_settings"]
    @type = @event["type"]
    @data = @event["data"]
  end

  def process!
    puts "RECEIVED NEW EVENT.."
    puts @event.inspect

    # TODO: handle event

    case @type
    when "register"
      register
    when "unregister"
      unregister
    when "update_settings"
      update_settings

    # TODO: handle other types here
    end
  end

  def register
    # handle register event
    puts "RECEIVED REGISTER EVENT"
  end

  def unregister
    # handle unregister event
    puts "RECEIVED UNREGISTER EVENT"
  end

  def update_settings
    # handle update_settings event
    puts "RECEIVED UPDATE_SETTINGS EVENT"
  end

end