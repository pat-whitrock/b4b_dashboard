require 'net/http'
require 'json'
require 'dotenv/load'

Dotenv.load

DISTRIBUTION_COUNT_QUERY_ID = 1734
PARTICIPANTS_BY_STATE_QUERY_ID = 1742

REDASH_RESULTS_FOR = ->(query_id) {
  JSON.parse(
    Net::HTTP.get(
      URI("https://redash.betterment.com/api/queries/#{query_id}/results.json?api_key=#{ENV['REDASH_API_KEY']}")
    )
  )
}

DISTRIBUTION_COUNT = -> {
  REDASH_RESULTS_FOR.(DISTRIBUTION_COUNT_QUERY_ID)['query_result']['data']['rows'].first['count']
}

PARTICIPANTS_BY_STATE = -> {
  REDASH_RESULTS_FOR.(PARTICIPANTS_BY_STATE_QUERY_ID)['query_result']['data']['rows'].sort_by do |row|
    -row['count']
  end.take(15).map do |row|
    { label: row['state'], value: row['count'] }
  end
}

SCHEDULER.every '60s', first_in: 0 do
  distribution_count = DISTRIBUTION_COUNT.()
  send_event('distribution_count', { current: distribution_count, previous: distribution_count })

  participants_by_state = PARTICIPANTS_BY_STATE.()
  send_event('participants_by_state', { items: participants_by_state })
end
