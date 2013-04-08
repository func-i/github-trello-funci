require 'open-uri'
require 'json'
require 'yaml'
require 'net/http'
require 'cgi'
require 'pry'

uri = URI("https://api.trello.com")
token = CGI::escape "d7dcd4b4044880e131fd7f0c570ec52d5095e9664eeb24ca1c43f93f5f47623d"
api_key = CGI::escape "ed810d3cbaf7cee3a7faa1d2ab808be3"

http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE

card_id = 296
board_id = "50aa59661970b5d45d00b7be"
request_path = "/1/boards/#{board_id}/cards/#{card_id}?key=#{api_key}&token=#{token}&fields=idList&actions=commentCard"

http.start

response = http.request_get(request_path)
response = JSON.parse response.body

binding.pry
