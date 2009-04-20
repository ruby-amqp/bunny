module AMQP
	%w[ spec buffer protocol frame client ].each do |file|
    require "amqp/#{file}"
  end
end