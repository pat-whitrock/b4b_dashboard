require 'net/http'
require 'json'
require 'dotenv/load'

Dotenv.load

DISTRIBUTION_COUNT_QUERY_ID = 1734
ACTIVE_PLAN_COUNT_QUERY_ID = 1741
PARTICIPANTS_BY_STATE_QUERY_ID = 1742
TOTAL_B4B_AUM_QUERY_ID = 1738
ON_CALL_COUNT_QUERY_ID = 1737
ON_CALL_BY_MONTH_QUERY_ID = 1744
CURRENT_PERIOD_APPROVED_PAPERLESS_DISTRIBUTIONS_QUERY_ID = 1747
PREVIOUS_PERIOD_APPROVED_PAPERLESS_DISTRIBUTIONS_QUERY_ID = 1748
CURRENT_PERIOD_DISTRIBUTIONS_QUERY_ID = 1750
PREVIOUS_PERIOD_DISTRIBUTIONS_QUERY_ID = 1749
B4B_AUM_BY_PLAN_ID = 1745

REDASH_RESULTS_FOR = ->(query_id) {
  JSON.parse(
    Net::HTTP.get(
      URI("https://redash.betterment.com/api/queries/#{query_id}/results.json?api_key=#{ENV['REDASH_API_KEY']}")
    )
  )
}

LATEST_PRIME_RATE = -> {
  newest_available_date = JSON.parse(
    Net::HTTP.get(
      URI("https://www.quandl.com/api/v3/datasets/FRED/DPRIME/metadata.json?api_key=#{ENV['QUANDL_API_KEY']}")
    )
  )['dataset']['newest_available_date']
  latest_prime_rate = JSON.parse(
    Net::HTTP.get(
      URI("https://www.quandl.com/api/v3/datasets/FRED/DPRIME.json?start_date=#{newest_available_date}&api_key=#{ENV['QUANDL_API_KEY']}")
    )
  )['dataset']['data'][0][1].to_s + '%'
}

DISTRIBUTION_COUNT = -> {
  REDASH_RESULTS_FOR.(DISTRIBUTION_COUNT_QUERY_ID)['query_result']['data']['rows'].first['count']
}

ACTIVE_PLAN_COUNT = -> {
  REDASH_RESULTS_FOR.(ACTIVE_PLAN_COUNT_QUERY_ID)['query_result']['data']['rows'].first['COUNT(id)']
}

PLANS_BY_AUM = -> {
  REDASH_RESULTS_FOR.(B4B_AUM_BY_PLAN_ID)['query_result']['data']['rows'].sort_by do |row|
    -row['Plan_AUM']
  end.take(20).map do |row|
    { label: row['Plan_Name'], value: row['Plan_AUM'] }
  end
}

PARTICIPANTS_BY_STATE = -> {
  REDASH_RESULTS_FOR.(PARTICIPANTS_BY_STATE_QUERY_ID)['query_result']['data']['rows'].sort_by do |row|
    -row['count']
  end.take(15).map do |row|
    { label: row['state'], value: row['count'] }
  end
}

TOTAL_B4B_AUM = -> {
  REDASH_RESULTS_FOR.(TOTAL_B4B_AUM_QUERY_ID)['query_result']['data']['rows'].first['AUM']
}

ON_CALL_COUNT = -> {
  REDASH_RESULTS_FOR.(ON_CALL_COUNT_QUERY_ID)['query_result']['data']['rows'].first['count']
}

ON_CALL_BY_MONTH = -> {
  REDASH_RESULTS_FOR.(ON_CALL_BY_MONTH_QUERY_ID)['query_result']['data']['rows'].each_with_index.map do |row, i|
    { x: i, y: row['count'] }
  end
}

CURRENT_PERIOD_APPROVED_PAPERLESS_DISTRIBUTIONS_COUNT = -> {
  REDASH_RESULTS_FOR.(CURRENT_PERIOD_APPROVED_PAPERLESS_DISTRIBUTIONS_QUERY_ID)['query_result']['data']['rows'].first['count']
}

PREVIOUS_PERIOD_APPROVED_PAPERLESS_DISTRIBUTIONS_COUNT = -> {
  REDASH_RESULTS_FOR.(PREVIOUS_PERIOD_APPROVED_PAPERLESS_DISTRIBUTIONS_QUERY_ID)['query_result']['data']['rows'].first['count']
}

CURRENT_PERIOD_DISTRIBUTIONS_COUNT = -> {
  REDASH_RESULTS_FOR.(CURRENT_PERIOD_DISTRIBUTIONS_QUERY_ID)['query_result']['data']['rows'].first['count']
}

PREVIOUS_PERIOD_DISTRIBUTIONS_COUNT = -> {
  REDASH_RESULTS_FOR.(PREVIOUS_PERIOD_DISTRIBUTIONS_QUERY_ID)['query_result']['data']['rows'].first['count']
}

CURRENT_PERIOD_PAPERLESS_DISTRIBUTION_RATIO = -> {
  (
    CURRENT_PERIOD_APPROVED_PAPERLESS_DISTRIBUTIONS_COUNT.() /
    CURRENT_PERIOD_DISTRIBUTIONS_COUNT.().to_f
  ).to_f * 100.0
}

PREVIOUS_PERIOD_PAPERLESS_DISTRIBUTION_RATIO = -> {
  (
    PREVIOUS_PERIOD_APPROVED_PAPERLESS_DISTRIBUTIONS_COUNT.() /
    PREVIOUS_PERIOD_DISTRIBUTIONS_COUNT.().to_f
  ).to_f * 100.0
}

SCHEDULER.every '60s', first_in: 0 do
  distribution_count = DISTRIBUTION_COUNT.()
  send_event('distribution_count', { current: distribution_count, previous: distribution_count })

  plans_by_aum = PLANS_BY_AUM.()
  send_event('plans_by_aum', { items: plans_by_aum })

  active_plan_count = ACTIVE_PLAN_COUNT.()
  send_event('active_plan_count', { current: active_plan_count, previous: active_plan_count })

  participants_by_state = PARTICIPANTS_BY_STATE.()
  send_event('participants_by_state', { items: participants_by_state })

  total_b4b_aum = TOTAL_B4B_AUM.()
  send_event('total_b4b_aum', { current: total_b4b_aum, previous: total_b4b_aum })

  on_call_count = ON_CALL_COUNT.()
  send_event('on_call_count', { current: on_call_count, previous: on_call_count })

  latest_prime_rate = LATEST_PRIME_RATE.()
  send_event('latest_prime_rate', { current: latest_prime_rate, previous: latest_prime_rate })

  on_call_by_month = ON_CALL_BY_MONTH.()
  send_event('on_call_by_month', { points: on_call_by_month })

  send_event(
    'paperless_distribution_ratio',
    {
      current: CURRENT_PERIOD_PAPERLESS_DISTRIBUTION_RATIO.().round(1),
      last: PREVIOUS_PERIOD_PAPERLESS_DISTRIBUTION_RATIO.().round(1)
    }
  )
end
