module Bunny
	
=begin rdoc

=== DESCRIPTION:

Queues store and forward messages. Queues can be configured in the server or created at runtime.
Queues must be attached to at least one exchange in order to receive messages from publishers.

=end

	class Queue < Qrack::Queue

	  def initialize(client, name, opts = {})
			# check connection to server
			raise Bunny::ConnectionError, 'Not connected to server' if client.status == :not_connected
			
	    @client = client
	    @opts   = opts
      @delivery_tag = nil
      @subscription = nil

      # Queues without a given name are named by the server and are generally
      # bound to the process that created them.
      if !name
        opts = {
          :passive => false,
          :durable => false,
          :exclusive => true,
          :auto_delete => true
        }.merge(opts)
      end
	
			# ignore the :nowait option if passed, otherwise program will hang waiting for a
			# response that will not be sent by the server
			opts.delete(:nowait)
			
	    client.send_frame(
	      Qrack::Protocol::Queue::Declare.new({ :queue => name || '', :nowait => false }.merge(opts))
	    )
	
      method = client.next_method

			client.check_response(method,	Qrack::Protocol::Queue::DeclareOk, "Error declaring queue #{name}")

      @name = method.queue
			client.queues[@name] = self
	  end

=begin rdoc

=== DESCRIPTION:

Acknowledges one or more messages delivered via the _Deliver_ or _Get_-_Ok_ methods. The client can
ask to confirm a single message or a set of messages up to and including a specific message.

==== OPTIONS:

* <tt>:delivery_tag</tt>
* <tt>:multiple => true or false (_default_)</tt> - If set to _true_, the delivery tag is treated
  as "up to and including", so that the client can acknowledge multiple messages with a single
  method. If set to _false_, the delivery tag refers to a single message. If the multiple field
  is _true_, and the delivery tag is zero, tells the server to acknowledge all outstanding messages.

=end
	
		def ack(opts={})
			# If delivery tag is nil then set it to 1 to prevent errors
			self.delivery_tag = opts[:delivery_tag] || 1
			
      client.send_frame(
        Qrack::Protocol::Basic::Ack.new({:delivery_tag => delivery_tag, :multiple => false}.merge(opts))
      )

			# reset delivery tag
			self.delivery_tag = nil
    end

=begin rdoc

=== DESCRIPTION:

Binds a queue to an exchange. Until a queue is bound it will not receive any messages. Queues are
bound to the direct exchange '' by default. If error occurs, a _Bunny_::_ProtocolError_ is raised.

* <tt>:key => 'routing key'* <tt>:key => 'routing_key'</tt> - Specifies the routing key for
  the binding. The routing key is used for routing messages depending on the exchange configuration.
* <tt>:nowait => true or false (_default_)</tt> - Ignored by Bunny, always _false_.

==== RETURNS:

<tt>:bind_ok</tt> if successful.

=end

	  def bind(exchange, opts = {})
	    exchange           = exchange.respond_to?(:name) ? exchange.name : exchange

			# ignore the :nowait option if passed, otherwise program will hang waiting for a
			# response that will not be sent by the server
			opts.delete(:nowait)

	    client.send_frame(
	      Qrack::Protocol::Queue::Bind.new({ :queue => name,
		 																:exchange => exchange,
		 																:routing_key => opts.delete(:key),
		 																:nowait => false }.merge(opts))
	    )
	
			method = client.next_method

			client.check_response(method,	Qrack::Protocol::Queue::BindOk,
				"Error binding queue: #{name} to exchange: #{exchange}")

			# return message
			:bind_ok
	  end
	
=begin rdoc

=== DESCRIPTION:

Requests that a queue is deleted from broker/server. When a queue is deleted any pending messages
are sent to a dead-letter queue if this is defined in the server configuration. Removes reference
from queues if successful. If an error occurs raises _Bunny_::_ProtocolError_.

==== Options:

* <tt>:if_unused => true or false (_default_)</tt> - If set to _true_, the server will only
  delete the queue if it has no consumers. If the queue has consumers the server does not
  delete it but raises a channel exception instead.
* <tt>:if_empty => true or false (_default_)</tt> - If set to _true_, the server will only
  delete the queue if it has no messages. If the queue is not empty the server raises a channel
  exception.
* <tt>:nowait => true or false (_default_)</tt> - Ignored by Bunny, always _false_.

==== Returns:

<tt>:delete_ok</tt> if successful
=end

	  def delete(opts = {})
			# ignore the :nowait option if passed, otherwise program will hang waiting for a
			# response that will not be sent by the server
			opts.delete(:nowait)

	    client.send_frame(
	      Qrack::Protocol::Queue::Delete.new({ :queue => name, :nowait => false }.merge(opts))
	    )
	
			method = client.next_method

			client.check_response(method,	Qrack::Protocol::Queue::DeleteOk, "Error deleting queue #{name}")

			client.queues.delete(name)

			# return confirmation
			:delete_ok
	  end

=begin rdoc

=== DESCRIPTION:

Gets a message from a queue in a synchronous way. If error occurs, raises _Bunny_::_ProtocolError_.

==== OPTIONS:
 
* <tt>:no_ack => true (_default_) or false</tt> - If set to _true_, the server does not expect an
  acknowledgement message from the client. If set to _false_, the server expects an acknowledgement
  message from the client and will re-queue the message if it does not receive one within a time specified
  by the server.

==== RETURNS:

Hash <tt>{:header, :delivery_details, :payload}</tt>. <tt>:delivery_details</tt> is
a hash <tt>{:delivery_tag, :redelivered, :exchange, :routing_key, :message_count}</tt>.

=end

	  def pop(opts = {})
			
			# do we want to have to provide an acknowledgement?
			ack = opts.delete(:ack)
			
	    client.send_frame(
	      Qrack::Protocol::Basic::Get.new({ :queue => name,
																	 :consumer_tag => name,
																	 :no_ack => !ack,
																	 :nowait => true }.merge(opts))
	    )
	
			method = client.next_method
			
			if method.is_a?(Qrack::Protocol::Basic::GetEmpty) then
				return {:header => nil, :payload => :queue_empty, :delivery_details => nil}
			elsif	!method.is_a?(Qrack::Protocol::Basic::GetOk)
				raise Bunny::ProtocolError, "Error getting message from queue #{name}"
			end
			
			# get delivery tag to use for acknowledge
			self.delivery_tag = method.delivery_tag if ack
			
	    header = client.next_payload
	
	    # If maximum frame size is smaller than message payload body then message
			# will have a message header and several message bodies
			msg = ''
			while msg.length < header.size
				msg += client.next_payload
			end

			# Return message with additional info if requested
			{:header => header, :payload => msg, :delivery_details => method.arguments}
			
	  end
	
=begin rdoc

=== DESCRIPTION:

Removes all messages from a queue.  It does not cancel consumers.  Purged messages are deleted
without any formal "undo" mechanism. If an error occurs raises _Bunny_::_ProtocolError_.

==== Options:

* <tt>:nowait => true or false (_default_)</tt> - Ignored by Bunny, always _false_.

==== Returns:

<tt>:purge_ok</tt> if successful
=end

		def purge(opts = {})
			# ignore the :nowait option if passed, otherwise program will hang waiting for a
			# response that will not be sent by the server
			opts.delete(:nowait)

	    client.send_frame(
	      Qrack::Protocol::Queue::Purge.new({ :queue => name, :nowait => false }.merge(opts))
	    )
	
			method = client.next_method

			client.check_response(method,	Qrack::Protocol::Queue::PurgeOk, "Error purging queue #{name}")

			# return confirmation
			:purge_ok

	  end

=begin rdoc

=== DESCRIPTION:

Returns hash {:message_count, :consumer_count}.

=end
 
	  def status
	    client.send_frame(
	      Qrack::Protocol::Queue::Declare.new({ :queue => name, :passive => true })
	    )
	    method = client.next_method
	    {:message_count => method.message_count, :consumer_count => method.consumer_count}
	  end

	
    def subscribe(opts = {}, &blk)
			# Create subscription
			s = Bunny::Subscription.new(client, self, opts)
			s.start(&blk)
			
			# Reset when subscription finished
			@subscription = nil
		end
		
=begin rdoc

=== DESCRIPTION:

Cancels a consumer. This does not affect already delivered messages, but it does mean
the server will not send any more messages for that consumer.

==== OPTIONS:

* <tt>:consumer_tag => '_tag_'</tt> - Specifies the identifier for the consumer.
* <tt>:nowait => true or false (_default_)</tt> - Ignored by Bunny, always _false_.

==== Returns:

<tt>:unsubscribe_ok</tt> if successful

=end
		
		def unsubscribe(opts = {})
			# Default consumer_tag from subscription if not passed in
			consumer_tag = subscription ? subscription.consumer_tag : opts[:consumer_tag]
			
			# Must have consumer tag to tell server what to unsubscribe
			raise Bunny::UnsubscribeError,
				"No consumer tag received" if !consumer_tag
			
      # Cancel consumer
      client.send_frame( Qrack::Protocol::Basic::Cancel.new(:consumer_tag => consumer_tag,
																														:nowait => false))

      raise Bunny::UnsubscribeError,
        "Error unsubscribing from queue #{name}" unless
        client.next_method.is_a?(Qrack::Protocol::Basic::CancelOk)

			# Reset subscription
			@subscription = nil
				
			# Return confirmation
			:unsubscribe_ok
			
    end

=begin rdoc

=== DESCRIPTION:

Removes a queue binding from an exchange. If error occurs, a _Bunny_::_ProtocolError_ is raised.

==== OPTIONS:
* <tt>:key => 'routing key'* <tt>:key => 'routing_key'</tt> - Specifies the routing key for
  the binding.
* <tt>:nowait => true or false (_default_)</tt> - Ignored by Bunny, always _false_.

==== RETURNS:

<tt>:unbind_ok</tt> if successful.

=end

	  def unbind(exchange, opts = {})
	    exchange = exchange.respond_to?(:name) ? exchange.name : exchange
	
			# ignore the :nowait option if passed, otherwise program will hang waiting for a
			# response that will not be sent by the server
			opts.delete(:nowait)

	    client.send_frame(
	      Qrack::Protocol::Queue::Unbind.new({ :queue => name,
		 																	:exchange => exchange,
		 																	:routing_key => opts.delete(:key),
		 																	:nowait => false }.merge(opts)
	      )
	    )
	
			method = client.next_method

			client.check_response(method,	Qrack::Protocol::Queue::UnbindOk, "Error unbinding queue #{name}")
				
			# return message
			:unbind_ok
	  end
	
		private
		
		def exchange
	    @exchange ||= Bunny::Exchange.new(client, '', {:type => :direct, :key => name})
	  end
	
	end
	
end
