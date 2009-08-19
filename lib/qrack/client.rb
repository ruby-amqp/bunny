module Qrack
	# Client ancestor class
	class Client
		
		CONNECT_TIMEOUT = 1.0
    RETRY_DELAY     = 10.0

    attr_reader   :status, :host, :vhost, :port, :logging, :spec, :heartbeat
    attr_accessor :channel, :logfile, :exchanges, :queues, :channels, :message_in, :message_out,
 									:connecting

	end
end