# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

def initialize(...)
	super
	
	require "async/container/supervisor"
end

# Restart the container, typically causing it to exit (the parent process should then restart it).
def restart
	client do |connection|
		connection.call(do: :restart)
	end
end

# Reload the services gracefully, allowing them to reconfigure without dropping connections.
def reload
	client do |connection|
		connection.call(do: :restart, signal: :HUP)
	end
end

def status
	client do |connection|
		connection.call(do: :status)
	end
end

# Sample memory allocations from a worker over a time period.
#
# This is useful for identifying memory leaks by tracking allocations
# that are retained after garbage collection.
#
# @parameter duration [Integer] The duration in seconds to sample for (default: 10).
# @parameter connection_id [String] The connection ID to target a specific worker.
def memory_sample(duration: 10, connection_id:)
	client do |connection|
		Console.info(self, "Sampling memory from worker...", duration: duration, connection_id: connection_id)
		
		# Build the operation request:
		operation = {do: :memory_sample, duration: duration}
		
		# Use the forward operation to proxy the request to a worker:
		return connection.call(do: :forward, operation: operation, connection_id: connection_id)
	end
end

private

def endpoint
	Async::Container::Supervisor.endpoint
end

def client(&block)
	Sync do
		Async::Container::Supervisor::Client.new(endpoint: self.endpoint).connect(&block)
	end
end
