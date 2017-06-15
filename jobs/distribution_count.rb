require 'net/http'
require 'json'
require 'dotenv/load'

Dotenv.load

DISTRIBUTION_COUNT_URI = URI(
  "https://redash.betterment.com/api/queries/1734/results.json?api_key=#{ENV['REDASH_API_KEY']}"
).freeze

SCHEDULER.every '2s' do
  distribution_count = JSON.parse(Net::HTTP.get(DISTRIBUTION_COUNT_URI))['query_result']['data']['rows'].first['count']

  send_event('distribution_count', { current: distribution_count, previous: distribution_count })
end
