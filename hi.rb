require 'rubygems'
require 'sinatra' 
require 'fileutils'
require 'net/http' 
require 'erb'
DIR='e:/kino/'
EXT='avi'
IP='192.168.100.183'
SmbPATH='smb://dib/kino/'

helpers do
  def stop
	'{"jsonrpc": "2.0", "method": "Player.Stop", "params": {"playerid":1}, "id": 3}'
  end
  def start(file)
    '{"jsonrpc": "2.0", "method": "Player.Open", "params": {"item":{"file":"'+SmbPATH+file+'"}}, "id": 3}'
  end
end

get '/' do
	redirect '/list'
end

get '/list' do
	files=Dir.foreach(DIR).grep(/#{EXT}$/)
	@list=files.map {|file| "<li><a href=\"/kinos/#{file}\">#{file[0..-5]}</a></li>"}.join	
	erb :list
end
get '/kinos/:file' do
	http=Net::HTTP.new(IP,8080)
	http.post("/jsonrpc",stop)
	http.post("/jsonrpc",start(params[:file]))
	redirect '/list'
end