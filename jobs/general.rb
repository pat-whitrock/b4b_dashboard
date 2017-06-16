require 'net/http'
require 'json'
require 'dotenv/load'
require 'action_view'

Dotenv.load

include ActionView::Helpers::NumberHelper

DISTRIBUTION_COUNT_QUERY_ID = 1734
ACTIVE_PLAN_COUNT_QUERY_ID = 1741
PARTICIPANTS_BY_STATE_QUERY_ID = 1742
TOTAL_B4B_AUM_QUERY_ID = 1738
ON_CALL_COUNT_QUERY_ID = 1737
ON_CALL_BY_MONTH_QUERY_ID = 1744
CURRENT_PERIOD_APPROVED_PAPERLESS_DISTRIBUTIONS_QUERY_ID = 1747
PREVIOUS_PERIOD_APPROVED_PAPERLESS_DISTRIBUTIONS_QUERY_ID = 1748
CASHFLOW_BY_MONTH_QUERY_ID = 1746
FEES_BY_MONTH_QUERY_ID = 1757
CURRENT_PERIOD_DISTRIBUTIONS_QUERY_ID = 1750
PREVIOUS_PERIOD_DISTRIBUTIONS_QUERY_ID = 1749
YTD_DISTRIBUTION_TOTALS_QUERY_ID = 1754
YTD_CONTRIBUTION_TOTALS_QUERY_ID = 1756
B4B_AUM_BY_PLAN_QUERY_ID = 1745
NINETY_DAY_CONTRIBUTION_TOTALS_QUERY_ID = 1759
NINETY_DAY_DISTRIBUTION_TOTALS_QUERY_ID = 1760
MATE_COUNT_QUERY_ID = 1758
RETAIL_DEPOSITS_QUERY_ID = 1761
MOST_RECENT_PAYROLL_BY_PLAN_QUERY_ID = 1762

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
  '4.25%'
}

DISTRIBUTION_COUNT = -> {
  REDASH_RESULTS_FOR.(DISTRIBUTION_COUNT_QUERY_ID)['query_result']['data']['rows'].first['count']
}

ACTIVE_PLAN_COUNT = -> {
  REDASH_RESULTS_FOR.(ACTIVE_PLAN_COUNT_QUERY_ID)['query_result']['data']['rows'].first['COUNT(id)']
}

PLANS_BY_AUM = -> {
  REDASH_RESULTS_FOR.(B4B_AUM_BY_PLAN_QUERY_ID)['query_result']['data']['rows'].sort_by do |row|
    -row['Plan_AUM']
  end.take(20).map do |row|
    { label: row['Plan_Name'], column_one: number_to_currency(row['Plan_AUM']), column_two: most_recent_payroll_amount_for_plan(row['Plan_ID']) }
  end
}

MOST_RECENT_PAYROLL_BY_PLAN = -> {
  REDASH_RESULTS_FOR.(MOST_RECENT_PAYROLL_BY_PLAN_QUERY_ID)['query_result']['data']['rows'].sort_by do |row|
    -row['plan_id']
  end.map do |row|
    { plan_id: row['plan_id'], most_recent_payroll_amount: row['most_recent_payroll'] }
  end
}

def most_recent_payroll_amount_for_plan(plan_id)
  payroll_info = most_recent_payroll_by_plan.detect{|row| row[:plan_id] == plan_id }
  payroll_amount = payroll_info[:most_recent_payroll_amount]
  number_to_currency(payroll_amount)
end

def most_recent_payroll_by_plan
  MOST_RECENT_PAYROLL_BY_PLAN.()
end

PARTICIPANTS_BY_STATE = -> {
  REDASH_RESULTS_FOR.(PARTICIPANTS_BY_STATE_QUERY_ID)['query_result']['data']['rows'].sort_by do |row|
    -row['count']
  end.take(15).map do |row|
    { label: row['state'], value: number_with_delimiter(row['count']) }
  end
}

TOTAL_B4B_AUM = -> {
  REDASH_RESULTS_FOR.(TOTAL_B4B_AUM_QUERY_ID)['query_result']['data']['rows'].first['AUM']
}

ON_CALL_COUNT = -> {
  REDASH_RESULTS_FOR.(ON_CALL_COUNT_QUERY_ID)['query_result']['data']['rows'].first['count']
}

ON_CALL_BY_MONTH = -> {
  REDASH_RESULTS_FOR.(ON_CALL_BY_MONTH_QUERY_ID)['query_result']['data']['rows'].map do |row|
    { x: row['code'].to_i, y: row['count'] }
  end
}

CASHFLOW_BY_MONTH = -> {
  REDASH_RESULTS_FOR.(CASHFLOW_BY_MONTH_QUERY_ID)['query_result']['data']['rows'].map do |row|
    { x: row['code'].to_i, y: row['amount'] }
  end
}

FEES_BY_MONTH = -> {
  REDASH_RESULTS_FOR.(FEES_BY_MONTH_QUERY_ID)['query_result']['data']['rows'].map do |row|
    { x: row['code'].to_i, y: row['amount'] }
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

MATE_COUNT = -> {
  REDASH_RESULTS_FOR.(MATE_COUNT_QUERY_ID)['query_result']['data']['rows'].first['count']
}

YTD_RETAIL_DEPOSITS = -> {
  REDASH_RESULTS_FOR.(RETAIL_DEPOSITS_QUERY_ID)['query_result']['data']['rows'].first['amount']
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

YTD_DISTRIBUTION_TOTALS = -> {
  REDASH_RESULTS_FOR.(YTD_DISTRIBUTION_TOTALS_QUERY_ID)['query_result']['data']['rows'].first['ytd_distributions']
}

YTD_CONTRIBUTION_TOTALS = -> {
  REDASH_RESULTS_FOR.(YTD_CONTRIBUTION_TOTALS_QUERY_ID)['query_result']['data']['rows'].first['ytd_contributions']
}

NINETY_DAY_DISTRIBUTION_TOTALS = -> {
  REDASH_RESULTS_FOR.(NINETY_DAY_DISTRIBUTION_TOTALS_QUERY_ID)['query_result']['data']['rows'].first['ninety_day_distributions']
}

NINETY_DAY_CONTRIBUTION_TOTALS = -> {
  REDASH_RESULTS_FOR.(NINETY_DAY_CONTRIBUTION_TOTALS_QUERY_ID)['query_result']['data']['rows'].first['ninety_day_contributions']
}

SCHEDULER.every '60s', first_in: 0 do
  distribution_count = DISTRIBUTION_COUNT.()
  send_event('distribution_count', { current: distribution_count, previous: distribution_count })

  plans_by_aum = PLANS_BY_AUM.()
  send_event('plans_by_aum', { items: plans_by_aum })

  active_plan_count = ACTIVE_PLAN_COUNT.()
  send_event('active_plan_count', { current: active_plan_count, previous: active_plan_count })

  mate_count = MATE_COUNT.()
  send_event('mate_count', { current: mate_count, previous: mate_count })

  ytd_retail_deposits = YTD_RETAIL_DEPOSITS.()
  send_event('ytd_retail_deposits', { current: ytd_retail_deposits, previous: ytd_retail_deposits })

  participants_by_state = PARTICIPANTS_BY_STATE.()
  send_event('participants_by_state', { items: participants_by_state })

  total_b4b_aum = TOTAL_B4B_AUM.()
  send_event('total_b4b_aum', { current: total_b4b_aum, previous: total_b4b_aum })

  on_call_count = ON_CALL_COUNT.()
  send_event('on_call_count', { current: on_call_count, previous: on_call_count })

  on_call_by_month = ON_CALL_BY_MONTH.()
  send_event('on_call_by_month', { points: on_call_by_month })

  send_event(
    'paperless_distribution_ratio',
    {
      current: CURRENT_PERIOD_PAPERLESS_DISTRIBUTION_RATIO.().round(1),
      last: PREVIOUS_PERIOD_PAPERLESS_DISTRIBUTION_RATIO.().round(1)
    }
  )

  cashflow_by_month = CASHFLOW_BY_MONTH.()
  send_event('cashflow_by_month', { points: cashflow_by_month })

  fees_by_month = FEES_BY_MONTH.()
  send_event('fees_by_month', { points: fees_by_month })

  ytd_distribution_totals = YTD_DISTRIBUTION_TOTALS.()
  send_event('ytd_distribution_totals', { current: ytd_distribution_totals, previous: ytd_distribution_totals })

  ytd_contribution_totals = YTD_CONTRIBUTION_TOTALS.()
  send_event('ytd_contribution_totals', { current: ytd_contribution_totals, previous: ytd_contribution_totals })

  ninety_day_distribution_totals = NINETY_DAY_DISTRIBUTION_TOTALS.()
  send_event('ninety_day_distribution_totals', { current: ninety_day_distribution_totals, previous: ninety_day_distribution_totals })

  ninety_day_contribution_totals = NINETY_DAY_CONTRIBUTION_TOTALS.()
  send_event('ninety_day_contribution_totals', { current: ninety_day_contribution_totals, previous: ninety_day_contribution_totals })

  latest_prime_rate = LATEST_PRIME_RATE.()
  send_event('latest_prime_rate', { current: latest_prime_rate, previous: latest_prime_rate })
end
