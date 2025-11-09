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
		event = registration_monitor.pop
		connection = event.connection
		
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
			
			event = registration_monitor.pop
			connection = event.connection
			
			path = File.join(@root, "memory.json")
			connection.call(do: :memory_dump, path: path)
			
			expect(File.size(path)).to be > 0
		ensure
			worker_task&.stop
		end
	end
	
	with "do: :forward" do
		it "forwards operations to workers via connection_id" do
			worker = Async::Container::Supervisor::Worker.new(state, endpoint: endpoint)
			worker_task = worker.run
			
			# Wait for worker to register
			sleep(0.001) until server.connections.any?
			
			# Get the worker's connection_id
			connection_id = server.connections.keys.first
			
			# Create a client connection to the supervisor
			client_peer = endpoint.connect
			client_conn = Async::Container::Supervisor::Connection.new(client_peer, 0)
			
			# Need a dummy target for the background reader - use an empty object
			reader_target = Object.new
			def reader_target.dispatch(call)
				# Client doesn't dispatch, it only receives responses
			end
			
			# Start the background reader so responses can be received
			client_conn.run_in_background(reader_target)
			
			# Forward a memory_sample operation through the supervisor
			result = client_conn.call(
				do: :forward,
				operation: {do: :memory_sample, duration: 1},
				connection_id: connection_id
			)
			
			# Verify we got the forwarded response
			expect(result).to have_keys(:report)
			expect(result[:report]).to have_keys(:total_allocated, :total_retained)
		ensure
			client_conn&.close
			worker_task&.stop
		end
		
		it "fails when forwarding to non-existent connection_id" do
			# Create a client connection (no worker registered)
			client_peer = endpoint.connect
			client_conn = Async::Container::Supervisor::Connection.new(client_peer, 0)
			
			reader_target = Object.new
			def reader_target.dispatch(call); end
			client_conn.run_in_background(reader_target)
			
			result = client_conn.call(
				do: :forward,
				operation: {do: :memory_sample, duration: 1},
				connection_id: "non-existent-id"
			)
			
			expect(result).to have_keys(:error)
			expect(result[:error]).to be == "Connection not found"
		ensure
			client_conn&.close
		end
	end
	
	with "do: :memory_sample" do
		it "can sample memory allocations" do
			worker = Async::Container::Supervisor::Worker.new(state, endpoint: endpoint)
			worker_task = worker.run
			
			event = registration_monitor.pop
			connection = event.connection
			
			# Sample for a short duration (1 second for test speed)
			result = connection.call(do: :memory_sample, duration: 1)
			
			# The result should contain a report
			expect(result).to have_keys(:report)
			expect(result[:report]).to have_keys(:total_allocated, :total_retained)
		ensure
			worker_task&.stop
		end
	end
end
