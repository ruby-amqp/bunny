require 'bunny'

conn = nil
loop do
  begin
    conn.close unless conn.nil?
    conn = Bunny.new(
      host: 'localhost:5672',
      automatic_recovery: false
    )
    conn.start
    ch = conn.create_channel
    q  = ch.queue('bunny.test', auto_delete: true)
    x  = ch.default_exchange

    q.subscribe do |_delivery_info, _metadata, _payload|
      nil
    end
  rescue StandardError => e
    puts "Caught during connection setup: #{e}, retrying..."
    # sleep 2
    retry
  end

  # publisher loop
  loop do
    x.publish('Hello!', routing_key: q.name)
    puts "#{conn.instance_variable_get('@channels').inspect}"
    STDERR.print "\n===#{Thread.list.count}===\n"
    Thread.list.each do |t|
      puts "Thread: #{t.object_id} #{t.status}"
    end
    sleep 0.01
  rescue StandardError => e
    puts "Caught: #{e}"
    break # attempt re-connect
  end
end
