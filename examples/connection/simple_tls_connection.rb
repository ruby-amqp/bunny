require 'uri'
require 'bunny'

# The certificate is NOT validated. This only tests
# that TLS is configured in an open fashion
# Don't use this anywhere that you care about security
def send_tls_amqp
  queue_name = 'testqueue'
  amqps_target = 'amqps://localhost:5001'
  msg_to_send = 'A test message'
  cert = 'certs/cert.pem'
  key = 'certs/key.pem'
  queue_options = {:auto_delete => true, :durable => false}
  uri = URI(amqp_target)

  connection = Bunny.new(
    {
      :host => uri.host,
      :port => uri.port,
      :ssl => uri.scheme.eql?('amqps'),
      :verify_ssl => false,
    }
  )
  connection.start

  channel = connection.create_channel
  q = channel.queue(queue_name, queue_options)
  x = channel.default_exchange
  
  x.publish("Test message", :routing_key => q.name)

  msg_info, msg_metadata, msg_content = q.pop
  puts "
  Meta: #{msg_metadata}
  Message: #{msg_content}
  ---
  Info: #{msg_info}
  "
end

send_tls_amqp
