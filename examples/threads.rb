begin
  loop do
    Thread.new do
      sleep 3600
    end
  end
rescue Exception
  puts "#{Thread.list.size} theads running"
end
