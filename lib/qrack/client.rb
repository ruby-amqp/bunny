module Qrack
	# Client ancestor class
	class Client
		
		CONNECT_TIMEOUT = 1.0
    RETRY_DELAY     = 10.0

    attr_reader   :status, :host, :vhost, :port, :logging, :spec
    attr_accessor :channel, :logfile, :exchanges, :queues

	end
end