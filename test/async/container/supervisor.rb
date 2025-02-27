# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/supervisor/a_server"

describe Async::Container::Supervisor do
	include Async::Container::Supervisor::AServer
	
	let(:state) do
		{process_id: ::Process.pid}
	end
	
	it "can connect to a server" do
		worker = Async::Container::Supervisor::Worker.new(state, endpoint: endpoint)
		connection = worker.connect
		
		# Wait for the client to connect to the server:
		sleep(0.001) until registration_monitor.registrations.any?
		
		connection = registration_monitor.registrations.first
		expect(connection.state).to have_keys(
			process_id: be == ::Process.pid
		)
	ensure
		connection&.close
	end
	
	with "do: :memory_dump" do
		it "can dump memory" do
			worker = Async::Container::Supervisor::Worker.new(state, endpoint: endpoint)
			worker_task = worker.run
			
			sleep(0.001) until registration_monitor.registrations.any?
			
			path = File.join(@root, "memory.json")
			connection = registration_monitor.registrations.first
			connection.call(do: :memory_dump, path: path)
			
			expect(File.size(path)).to be > 0
		ensure
			worker_task&.stop
		end
	end
end
