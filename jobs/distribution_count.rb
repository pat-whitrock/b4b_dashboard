SCHEDULER.every '2s' do
  send_event('distribution_count', { current: 100, previous: 100 })
end
