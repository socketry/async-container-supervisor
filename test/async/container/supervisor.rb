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
		
		# Wait for the client to connect to the server:
		sleep(0.001) until registration_monitor.registrations.any?
		
		connection = registration_monitor.registrations.first
		expect(connection.state).to have_keys(
			process_id: be == ::Process.pid
		)
	end
	
	with "do_memory_dump" do
		it "can dump memory" do
			instance = FakeInstance.new
			client = Async::Container::Supervisor::Client.new(instance, endpoint)
			client_task = client.run
			
			sleep(0.001) until registration_monitor.registrations.any?
			
			path = File.join(@root, "memory.json")
			connection = registration_monitor.registrations.first
			connection.call(do: :memory_dump, path: path)
			
			expect(File.size(path)).to be > 0
		ensure
			client_task&.stop
		end
	end
end
