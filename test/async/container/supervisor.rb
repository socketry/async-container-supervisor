# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/supervisor/a_server"

class FakeInstance
	def as_json(...)
		{process_id: ::Process.pid}
	end
	
	def to_json(...)
		as_json.to_json(...)
	end
end

describe Async::Container::Supervisor do
	include Async::Container::Supervisor::AServer
	
	it "can connect to a server" do
		instance = FakeInstance.new
		client = Async::Container::Supervisor::Client.new(instance, endpoint)
		connection = client.connect
		
		sleep(0.001) until registration_monitor.registrations.any?
		
		registration = registration_monitor.registrations.first
		expect(registration.state).to have_keys(
			process_id: be == ::Process.pid
		)
	end
end
