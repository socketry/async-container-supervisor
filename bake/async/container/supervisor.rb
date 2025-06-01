# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

def initialize(...)
	super
	
	require "async/container/supervisor"
end

def restart
	client do |connection|
		connection.call(do: :restart)
	end
end

def status
	client do |connection|
		connection.call(do: :status)
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
