require "sinatra/base"
require "multi_json"

Tilt.register Tilt::ERBTemplate, 'html.erb'

class LabRat < Sinatra::Base
  require 'sinatra/reloader' if development?

  configure do
    set :server, :puma
    set :views,  File.join(settings.root, 'views')
  end

  get "/" do
    erb :index
  end
end
