require 'net/http'
require 'json'
require 'dotenv/load'

Dotenv.load

DISTRIBUTION_COUNT_URI = URI(
  "https://redash.betterment.com/api/queries/1734/results.json?api_key=#{ENV['REDASH_API_KEY']}"
).freeze
PARTICIPANTS_BY_STATE_URI = URI(
  "https://redash.betterment.com/api/queries/488/results.json?api_key=#{ENV['REDASH_API_KEY']}"
).freeze

SCHEDULER.every '2s' do
  distribution_count = JSON.parse(Net::HTTP.get(DISTRIBUTION_COUNT_URI))['query_result']['data']['rows'].first['count']
  send_event('distribution_count', { current: distribution_count, previous: distribution_count })

  participants_by_state = JSON.parse(Net::HTTP.get(PARTICIPANTS_BY_STATE_URI))
  top_states = participants_by_state['query_result']['data']['rows'].sort_by do |row|
    -row['count']
  end.take(15).map do |row|
    { label: row['state'], value: row['count'] }
  end
  send_event('participants_by_state', { items: top_states })
end
