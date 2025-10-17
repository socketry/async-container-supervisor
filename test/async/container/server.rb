# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/supervisor/a_server"
require "sus/fixtures/console/null_logger"

describe Async::Container::Supervisor::Server do
	include Sus::Fixtures::Console::NullLogger
	include Async::Container::Supervisor::AServer
	
	it "can handle unexpected failures" do
		# First, send invalid JSON to trigger the error:
		endpoint.connect do |stream|
			# Send malformed JSON that will cause parsing errors:
			stream.write("not valid json\n")
			stream.flush
		end
		
		# Now send a valid message to confirm the server is still working:
		stream = endpoint.connect
		
		# Send a valid register message:
		message = {id: 1, do: :register, state: {process_id: ::Process.pid}}
		stream.puts(JSON.dump(message))
		stream.flush
		
		# Read the response:
		response = JSON.parse(stream.gets, symbolize_names: true)
		
		# The server should respond with a finished message:
		expect(response).to have_keys(
			id: be == 1,
			finished: be == true
		)
		
		stream.close
	end
	
	with "failing monitor" do
		let(:failing_monitor) do
			Class.new do
				def run
				end
				
				def register(connection)
				end
				
				def remove(connection)
				end
				
				def status(call)
					raise "Monitor failed to get status!"
				end
			end.new
		end
		
		let(:monitors) {[failing_monitor]}
		
		it "can handle monitor status failures" do
			# Send a status request:
			stream = endpoint.connect
			
			message = {id: 1, do: :status}
			stream.puts(JSON.dump(message))
			stream.flush
			
			# Read the response:
			response = JSON.parse(stream.gets, symbolize_names: true)
			
			# The server should still respond with a finished message despite the monitor error:
			expect(response).to have_keys(
					id: be == 1,
					finished: be == true,
					error: have_keys(
						class: be == "RuntimeError",
						message: be == "Monitor failed to get status!",
						backtrace: be_a(Array)
					)
				)
			
			stream.close
		end
	end
	
	it "handles responses arriving after timeout" do
		# This reproduces the production bug:
		# 1. Client makes a call with timeout.
		# 2. Timeout expires, call ID is deleted from tracking.
		# 3. Response arrives late.
		# 4. System should recognize it's a response (no 'do' key) and ignore it.
		stream = endpoint.connect
		
		# Simulate what happens when a timed-out response arrives:
		# The response only has id and finished (no 'do' key) because it's a response, not a request
		message = {id: 1, finished: true}
		stream.puts(JSON.dump(message))
		stream.flush
		
		# Send a valid message to confirm the server is still working:
		valid_message = {id: 3, do: :register, state: {process_id: ::Process.pid}}
		stream.puts(JSON.dump(valid_message))
		stream.flush
		
		# Read the response to the valid message:
		response = JSON.parse(stream.gets, symbolize_names: true)
		
		# The server should have ignored the stale response and processed the valid one:
		expect(response).to have_keys(
			id: be == 3,
			finished: be == true
		)
		
		stream.close
	end
	
	it "does not send error response for stale messages" do
		# Verify that stale messages are silently ignored, not treated as errors.
		# Before the fix, this would cause NoMethodError: undefined method 'do_'
		stream = endpoint.connect
		
		# Send a stale response:
		stale_message = {id: 5, finished: true}
		stream.puts(JSON.dump(stale_message))
		stream.flush
		
		# Send a valid message:
		valid_message = {id: 7, do: :register, state: {process_id: ::Process.pid}}
		stream.puts(JSON.dump(valid_message))
		stream.flush
		
		# We should only get ONE response - for the valid message.
		# Not an error response for the stale message.
		response = JSON.parse(stream.gets, symbolize_names: true)
		
		expect(response).to have_keys(
			id: be == 7,
			finished: be == true
		)
		
		# Verify the response is successful, not an error:
		expect(response[:failed]).to be_nil
		expect(response[:error]).to be_nil
		
		stream.close
	end
end