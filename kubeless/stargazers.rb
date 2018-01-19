require "net/https"
require "uri"
require "json"
require "logger"

def handler(request)
  webhook_url = ENV['WEBHOOK_URL']
  payload = JSON.parse(request.body.read)
  
  repo = payload['repository']['name']
  stars = payload['repository']['stargazers_count']
  username = payload['sender']['login']
  url = payload['sender']['html_url']

  text = "New Github star for *#{repo}* repo! It now has *#{stars}* stars! :tada:
Your new fan is <#{url}|#{username}>"
  
  uri = URI.parse(webhook_url)
  http = Net::HTTP.new(uri.host, 443)
  http.use_ssl = true

  request = Net::HTTP::Post.new(
    uri.request_uri,
    'Content-Type': 'application/json'
  )
  request.body = { 'text': text }.to_json
  response = http.request(request)
  
  logger = Logger.new(STDOUT)
  logger.info("Slack posted, responded #{response.code}.")
end
