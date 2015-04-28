######
# Addon Setup Task
# don't modify this file, it's automatically updated via `rake setup`
######

class AddonTask
  def initialize
    begin
      require 'yaml'
      require 'active_support/all'

      require 'github/markup'
      require "json"
      require "rest_client"
      require 'coffee-script'
      require 'sass'
      require 'cssminify'
      require 'uglifier'

    rescue Exception => e
      puts "\nMissing dependency: #{e.to_s}\n\n"

      show_error("Sorry, we're missing some dependencies. Please run `rake setup` to continue.")
    end

    read_settings
  end

  def read_settings
    addon_settings_path = File.expand_path("./addon.yml", File.dirname(__FILE__))

    unless File.exists?(addon_settings_path)
      show_error("Could not find ./addon.yml. Please run `rake setup` to continue.")
    end

    addon_settings = YAML.load_file(addon_settings_path)


    # default addon env to development
    environment = ENV["ADDON_ENV"].to_s.presence || "development"

    @addon = addon_settings.dup.except("environments")
    @server = addon_settings["environments"][environment]

    if @addon["name"].blank?
      show_error("please set a valid addon \"name\" setting in your addon.yml file")
    end

    # default host if not set
    @server["api_host"] = @server["api_host"].presence || "https://www.forwardtrail.com"
    puts "ForwardTrail Addon: #{@addon['name']}. environment: #{environment}"
    puts "host: #{@server['api_host']}"

    # get api key based on environment
    # TODO

    api_key = @server["api_key"]
    if api_key.blank? or api_key == "YOUR_API_KEY"
      puts "********"
      puts "Please fill out your 'api_key' in addon.yml (under 'environments' -> '#{environment}')"
      puts "api_key: YOUR_API_KEY"
      puts
      puts "You can get an API Key from your ForwardTrail team settings: "
      puts "Click on 'Integrations / Addons'"
      puts "********"
      puts
      exit
    end

    if @addon["secret"].blank? or @addon["secret"] == "GENERATE_NEW_SECRET"
      puts "********"
      puts "Please fill out your 'secret' in addon.yml"
      puts "secret: GENERATE_NEW_SECRET"
      puts
      puts "You can generate a new secret by running `rake secret`"
      puts "then replace GENERATE_NEW_SECRET with that generated string."
      puts "********"
      puts
      exit
    end

    @addon
  end

  def local_port
    require 'uri'
    URI.parse(@server["addon_url"]).port
  end

  def compile_sass(file)

    if File.extname(file) == ".sass"
      syntax = :sass
    elsif File.extname(file) == ".scss"
      syntax = :scss
    end

    if @addon["sass"].try(:[], "style").present?
      style = @addon["sass"].try(:[], "style").to_s.to_sym
    else
      style = :compact
    end

    engine = Sass::Engine.new(File.read(file), :syntax => syntax, :style => style)
    engine.render
  end

  def compile_css(file)
    css = File.read(file)

    if @addon["css"].try(:[], "minify")
      CSSminify.compress(css)
    else
      css
    end
  end

  def compile_coffee(file)
    js = CoffeeScript.compile File.read(file)

    if @addon["js"].try(:[], "minify")
      Uglifier.compile(js, :mangle => false)
    else
      js
    end
  end

  def compile_js(file)
    js = File.read(file)

    if @addon["js"].try(:[], "minify")
      Uglifier.compile(js, :mangle => false)
    else
      js
    end
  end

  def wrap_http
    begin
      yield
    rescue Errno::ECONNREFUSED => e
      show_error("ForwardTrail (#{@server['api_host']}) is not currently responding: \"#{e.message}\" **\n** Sorry about that! Please email this output to support@forwardtrail.com and we'll get back to you ASAP.")
    rescue RestClient::InternalServerError => e
      show_error("ForwardTrail ((#{@server['api_host']}) responded with a server error: \"#{e.message}\" **\n** Sorry about that! We'll look into it ASAP, please email us at support@forwardtrail.com.")
    rescue => e
      puts
      puts e.to_s
      puts
      show_error("ForwardTrail ((#{@server['api_host']}) responded with an error. **\n** Sorry about that! Please email this output to support@forwardtrail.com and we'll get back to you ASAP.")
    end
  end

  def compile_embedded_js(base_path)
    scripts = []

    Dir["#{base_path}/**/*.js"].each do |path|
      scripts << compile_js(path)
    end
    Dir["#{base_path}/**/*.coffee"].each do |path|
      scripts << compile_coffee(path)
    end

    scripts.join("\n\n")
  end

  def compile_embedded_css(base_path)
    stylesheets = []

    Dir["#{base_path}/**/*.sass"].each do |path|
      stylesheets << compile_sass(path)
    end
    Dir["#{base_path}/**/*.scss"].each do |path|
      stylesheets << compile_sass(path)
    end
    Dir["#{base_path}/**/*.css"].each do |path|
      stylesheets << compile_css(path)
    end

    stylesheets.join("\n\n")
  end

  def update_icon
    # upload icon
    icon_path = File.expand_path("./icon.png", File.dirname(__FILE__))
    if File.exists?(icon_path)
      wrap_http do
        request = RestClient::Request.new({
          method: :post,
          url: "#{@server['api_host']}/api/v1/addons/#{@addon['name']}/icon",
          headers: {
            :accept => :json,
            'X-API-KEY' => @server['api_key']
          },
          payload: {
            multipart: true,
            file: File.new(icon_path, "rb")
          }
        })
        result = request.execute
        if result.code == 200 and JSON.parse(result)["success"]
          puts "Addon: #{@addon['name']} icon uploaded."
        end
      end
    end

  end

  def install
    name = @addon["name"]

    # addon base path (current dir)
    addon_base = File.dirname(__FILE__)

    # verify addon settings
    if @addon["title"].blank? or @addon["short_description"].blank?
      show_error("please set valid \"title\" and \"short_description\" settings")
    end

    # generate description
    description_path = File.expand_path("./addon.md", addon_base)
    if File.exists?(description_path)
      # render description markup
      @addon["description"] = GitHub::Markup.render("README.md", File.read(description_path))
    end

    # compile addon options
    addon_options = []
    (@addon["options"].presence || {}).each do |key, val|
      val["name"] = key

      if val["title"].blank?
        val["title"] = key.to_s.camelize
      end

      if val["help"].present?
        val["help_html"] = GitHub::Markup.render("README.md", val["help"])
      end

      addon_options << val
    end
    @addon["settings"] = addon_options

    @addon["webhook"] = @server["addon_url"]

    # compile CSS
    embedded_css = compile_embedded_css("#{addon_base}/client")
    if embedded_css.present?
      @addon["embedded_css"] = embedded_css
    end

    # compile JS
    embedded_js = compile_embedded_js("#{addon_base}/client")
    if embedded_js.present?
      @addon["embedded_js"] = embedded_js
    end

    # generate JSON
    post_json = JSON.dump(@addon)

    # upload JSON
    # require 'byebug';byebug
    result = nil
    wrap_http do
      result = RestClient.post "#{@server['api_host']}/api/v1/addons", post_json, :content_type => :json, :accept => :json, 'X-API-KEY' => @server['api_key']
    end

    response = {}
    response = JSON.parse(result) if result.try(:code) == 200

    if response["success"]
      # only upload the icon if its blank (to change icon, remove and reinstall addon)
      icon_path = File.expand_path("./icon.png", File.dirname(__FILE__))
      if File.exists?(icon_path) and response["addon"].try(:[], "icon").blank?
        update_icon
      end
    else
      error_msg = ""
      if response["msg"]
        error_msg << " / Error: #{response["msg"]}"
      end
      if result.try(:code)
        error_msg << " / HTTP Code: #{result.try(:code)}"
      end

      show_error("Unable to upload addon: #{name}#{error_msg}")
    end

    puts "Addon: #{name} has been updated."
  end

  def uninstall
    wrap_http do
      result = RestClient.delete "#{@server['api_host']}/api/v1/addons/#{@addon['name']}",:content_type => :json, :accept => :json, 'X-API-KEY' => @server['api_key']

      response = {}
      response = JSON.parse(result) if result.try(:code) == 200

      if response["success"]
        puts "Addon: #{name} has been removed."
      end
    end
  end

  def self.setup
    puts "UPDATING TOOLS...\n"

    require 'open-uri'

    # update tools.rake
    setup_rake_content = open("https://raw.githubusercontent.com/forwardtrail/addon/master/setup.rake").read
    File.open(__FILE__, 'w') { |file| file.write(setup_rake_content) }

    # TODO: check dependencies on Gemfile, instruct user to add gem dependencies for anything missing

    # bundle gems
    system("bundle")

    puts "\n\nTools updated!\n\nNext steps:"
    puts "- `rake install` to install your addon to ForwardTrail"
    puts "- `foreman start` to run your addon server locally"
  end

  def show_error(msg)
    puts "** #{msg} **"
    exit
  end

end

desc "Install this Addon onto the ForwardTrail server"
task :install do
  AddonTask.new.install
end

desc "Updates the icon for this addon"
task :update_icon do
  AddonTask.new.update_icon
end

desc "Uninstall this Addon off of the ForwardTrail server"
task :uninstall do
  AddonTask.new.uninstall
end

desc "Pull the latest tools (setup.rake)"
task :setup do
  AddonTask.setup
end

desc "Start local dev server"
task :server do
  system("shotgun --server=puma --port=#{AddonTask.new.local_port} server/addon.rb")
end

desc "Generate a secret"
task :secret do
  require 'securerandom'
  puts SecureRandom.hex(64)
end