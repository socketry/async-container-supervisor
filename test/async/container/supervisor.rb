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
		wrapper = client.connect
		
		sleep(0.001) until server.registered.any?
		
		registration = server.registered.first
		expect(registration.last).to have_keys(
			action: be == "register",
			instance: be == instance.as_json,
		)
	end
end
