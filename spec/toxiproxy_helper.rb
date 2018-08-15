module RabbitMQ
  module Toxiproxy
    def setup_toxiproxy
      ::Toxiproxy.populate([{
        name: "rabbitmq",
        listen: "0.0.0.0:11111",
        upstream: "rabbitmq:5672"
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
