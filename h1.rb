DEBUG = false
LLOG_FILE = 'd:\\hi\\llog.log'
LOG_FILE = 'd:\\hi\\daemon.log'

require 'rubygems'
require 'sinatra' 
require 'fileutils'
require 'em-http-request'
require 'erb'
require 'json'

DIR='d:/avi/'
Sinatra_IP='192.168.1.103'
Sinatra_Port='9090'
AppleIPs=['192.168.1.101','192.168.1.104','192.168.1.100','192.168.1.105']#'178.137.146.195',

SmbPATH='smb://pc/avi/'
FileExtensions={
:Playlists=> %w(m3u),
:Pictures=> %w(jpg jpeg),
:Movies=> %w(mp4 m4v avi mpeg mpg)
}


class MySinatraApp < Sinatra::Base
  helpers do
    def rpc(meth, parms="")
      {jsonrpc:"2.0", method: meth, params:parms, id:4}.to_json
    end

    def stop
      rpc("Player.Stop", { playerid:1 } )
    end

    def play(file)
      rpc("Player.Open", {item: {file: file}})
    end
   
    def repeat(action)
      rpc("Player.Repeat", {playerid:1, state: action})
    end

    def apples(action)
      apple(0, action)
    end

    def apple(n, action)
      EventMachine.run do

        multi = EventMachine::MultiRequest.new
        apples= (n==0) ? AppleIPs : [AppleIPs[n-1]] 

        apples.each_with_index do |ip, idx|
          request=EventMachine::HttpRequest.new("http://#{ip}:8080/jsonrpc",
                                                :connect_timeout => 1,
                                                :inactivity_timeout => 1)
          multi.add idx, request.post(:body=>action)
        end
            
        multi.callback do
          if DEBUG 
            File.open(LLOG_FILE,'a+') do |f| 
              multi.responses[:callback].size.times { f.puts ':)'}
              multi.responses[:errback].size.times { f.puts ':('}
              f.puts multi.responses[:callback]
              f.puts multi.responses[:errback]
            end
          end
          EventMachine.stop
        end
      end
    end
  end

  get '/' do
    erb '<span data-role="controlgroup" data-type="horizontal">
    <a href="/list" data-role="button" data-theme="c">All</a>
    <a href="/1/list" data-role="button" data-theme="a">1</a>
    <a href="/2/list" data-role="button" data-theme="b">2</a>
    <a href="/3/list" data-role="button" data-theme="e">3</a>
    <a href="/4/list" data-role="button" data-theme="d">4</a>
    </span>'
  end

  get %r{/([\d])/list/?} do
    n=params[:captures].first
    @list="<h1 style=\"text-align: center\">Apple TV ##{n}</h1><br/>"
    FileExtensions.each {|section, extensions| 
      @list<<%{<li data-role="list-divider" role="heading">}+section.to_s+"</li>\n"
    
      files=Dir.foreach(DIR).grep(/(#{extensions.join('|')})$/) 

      @list<<files.map {|file|
          %{<li><a data-ajax="false" href=\"/#{n}/play/#{file}\">#{file[0..-5]}</a></li>}
      }.join
    }
    erb :list  
end

  get '/list' do
    @list=''
    FileExtensions.each {|section,extensions| 
      @list<<%{<li data-role="list-divider" role="heading">}+section.to_s+"</li>\n"
    
      files=Dir.foreach(DIR).grep(/(#{extensions.join('|')})$/) 

      @list<<files.map {|file|
          %{<li><a data-ajax="false" href=\"/play/#{file}\">#{file[0..-5]}</a></li>}
      }.join
    }
    erb :list
  end

  get '/repeat/:action' do
    apples repeat params[:action] 
  	redirect '/'
  end


  get '/play/:file' do
    if params[:file].match(/#{FileExtensions[:Movies].join('|')}$/)  
      file_url="http://#{Sinatra_IP}:#{Sinatra_Port}/m3u/#{URI.encode_www_form_component(params[:file])}.m3u"
    else 
      file_url=SmbPATH+params[:file]
    end
    
    apples play file_url

    redirect '/'
  end

   get %r{/([\d])/play/(.*)} do
     n=params[:captures].first.to_i
     file=params[:captures].last
     
      if file.match(/#{FileExtensions[:Movies].join('|')}$/)  
        file_url="http://#{Sinatra_IP}:#{Sinatra_Port}/m3u/#{URI.encode_www_form_component(file)}.m3u"
      else 
        file_url=SmbPATH+file
      end
      
      apple n, play file_url

      redirect '/'
  end

  get '/m3u/:file' do
    content_type 'audio/x-mpegurl'
    SmbPATH+URI.decode_www_form_component(params[:file])[0..-5]
  end

end

begin
  require 'win32/daemon'
  include Win32
  $stdout.reopen("thin-server.log", "w")
  $stdout.sync = true
  $stderr.reopen($stdout)

  class Daemon
    def service_main
      #puts 'hi'
      MySinatraApp.run! :host => 'tureyzahav.sytes.net', :port => Sinatra_Port, :server => 'webrick'
      #puts 'bye'
      while running?
        sleep 10
        File.open(LOG_FILE, "a"){ |f| f.puts "Service is running #{Time.now}" }
      end
    end

    def service_stop
      File.open(LOG_FILE, "a"){ |f| f.puts "***Service stopped #{Time.now}" }
      exit!
    end
  end

  Daemon.mainloop

rescue Exception => err
  File.open(LOG_FILE,'a+'){ |f| f.puts " ***Daemon failure #{Time.now} err=#{err} " }
  raise
end
