require 'bundler'
Bundler.setup
require 'sinatra'
require 'json'
require 'byebug'
require File.join(File.expand_path('../../..', __FILE__), 'coffeescript/processor')

ClientSideValidations::Processor.run

class AssetPath < Rack::Static
  def call(env)
    path = env['PATH_INFO']

    if can_serve(path)
      env['PATH_INFO'] = (path == '/' ? @index : @urls[path]) if overwrite_file_path(path)
      response = @file_server.call(env)
      if response.first == 404
        @app.call(env)
      else
        response
      end
    else
      @app.call(env)
    end
  end
end

use AssetPath, urls: ['/vendor/assets/javascripts'], root: File.expand_path('../..', settings.root)
use AssetPath, urls: ['/vendor/assets/javascripts'], root: File.expand_path('../', $LOAD_PATH.find { |p| p =~ /jquery-rails/ })

JQUERY_VERSIONS = %w(1.11.3 1.12.4 2.0.3 2.1.4 2.2.4 3.0.0 3.1.1).freeze

helpers do
  def jquery_link(version)
    if params[:version] == version
      "[#{version}]"
    else
      "<a href='/?version=#{version}'>#{version}</a>"
    end
  end

  def jquery_src
    if params[:version] == 'edge' then '/vendor/jquery.js'
    else "https://code.jquery.com/jquery-#{params[:version]}.js"
    end
  end

  def test_base
    names = ['/vendor/qunit.js', 'settings']
    names.map { |name| script_tag name }.join("\n")
  end

  def test(*types)
    types.map do |type|
      Dir.glob(File.expand_path("public/test/#{type}", settings.root) + '/*.js').map { |file| File.basename(file) }.map do |file|
        script_tag "/test/#{type}/#{file}"
      end.join("\n")
    end.join("\n")
  end

  def script_tag(src)
    src = "/test/#{src}.js" unless src.index('/')
    %(<script src='#{src}' type='text/javascript'></script>)
  end

  def jquery_versions
    JQUERY_VERSIONS
  end
end

get '/' do
  params[:version] ||= JQUERY_VERSIONS.last
  erb :index
end

post '/users' do
  data = { params: params }.update(request.env)
  payload = data.to_json.gsub('<', '&lt;').gsub('>', '&gt;')
  <<-HTML
    <script>
      if (window.top && window.top !== window)
        window.top.jQuery.event.trigger('iframe:loaded', #{payload})
    </script>
    <p id="response">Form submitted</p>
  HTML
end
