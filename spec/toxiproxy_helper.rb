module RabbitMQ
  module Toxiproxy
    RABBITMQ_UPSTREAM_HOST = if !ENV["LOCAL_RABBITMQ"].nil?
                               # a local Toxiproxy/RabbitMQ combination
                               "localhost"
                             else
                               # docker-compose
                               "rabbitmq"
                             end

    def setup_toxiproxy
      ::Toxiproxy.populate([{
        name: "rabbitmq",
        listen: "0.0.0.0:11111",
            upstream: "#{RABBITMQ_UPSTREAM_HOST}:5672"
      }])
      rabbitmq_toxiproxy.enable
    end

    def cleanup_toxiproxy
      ::Toxiproxy.populate()
    end

    def rabbitmq_toxiproxy
      ::Toxiproxy[/rabbitmq/]
    end
  end
end
