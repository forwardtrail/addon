class Event
  def initialize(data)
    @data = data.with_indifferent_hash
    @account = @data["account"]
    @addon = @data["addon"]
    @event = @data["event"]
  end

  def process!
    puts "RECEIVED NEW EVENT.."
    puts event.inspect

    # TODO: handle event

    case @event["type"]
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