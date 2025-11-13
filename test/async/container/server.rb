# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/supervisor/a_server"
require "sus/fixtures/console/captured_logger"

describe Async::Container::Supervisor::Server do
	include Async::Container::Supervisor::AServer
	include Sus::Fixtures::Console::CapturedLogger
	
	def write_message(stream, message)
		Async::Container::Supervisor::MessageWrapper.new(stream).write(message)
	end
	
	def read_message(stream)
		Async::Container::Supervisor::MessageWrapper.new(stream).read
	end
	
	it "can handle unexpected failures" do
		# First, send invalid JSON to trigger the error:
		endpoint.connect do |stream|
			# Send malformed data (just 2 bytes claiming huge size, but no actual data):
			stream.write([999999].pack("N"))
			stream.flush
		end
		
		# Now send a valid message to confirm the server is still working:
		stream = endpoint.connect
		
		# Send a valid register message:
		message = {id: 1, do: :register, state: {process_id: ::Process.pid}}
		write_message(stream, message)
		
		# Read the response:
		response = read_message(stream)
		
		# The server should respond with a finished message:
		expect(response).to have_keys(
			id: be == 1,
			finished: be == true
		)
		
		stream.close
		
		# Verify error was logged about the parsing failure
		error_logs = console_capture.select{|log| log[:severity] == :warn}
		expect(error_logs).not.to be(:empty?)
	end
	
	with "failing monitor" do
		let(:failing_monitor) do
			Class.new do
				def run
				end
				
				def register(connection)
					raise "Monitor failed to register!"
				end
				
				def remove(connection)
					raise "Monitor failed to remove!"
				end
				
				def status(call)
					raise "Monitor failed to get status!"
				end
			end.new
		end
		
		let(:monitors) {[failing_monitor]}
		
		it "can handle monitor registration failures" do
			# Send a register message:
			stream = endpoint.connect
			
			message = {id: 1, do: :register, state: {process_id: ::Process.pid}}
			write_message(stream, message)
			
			# Read the response:
			response = read_message(stream)
			
			# The server should still finish despite the monitor error:
			expect(response).to have_keys(
				id: be == 1,
				finished: be == true
			)
			
			# Verify error was logged about the monitor failure:
			error_log = console_capture.find{|log| log[:severity] == :error && log[:message] =~ /Error while registering process/}
			expect(error_log).to be_truthy
			
			stream.close
		end
		
		it "can handle monitor status failures" do
			# Send a status request:
			stream = endpoint.connect
			
			message = {id: 1, do: :status}
			write_message(stream, message)
			
			# Read the response:
			response = read_message(stream)
			
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
		
		it "can handle monitor removal failures" do
			# Connect then disconnect to trigger removal:
			stream = endpoint.connect
			stream.close
			
			# Give time for removal to process
			reactor.sleep(0.01)
			
			# Verify error was logged about the monitor removal failure:
			error_log = console_capture.find{|log| log[:severity] == :error && log[:message] =~ /Error while removing process/}
			expect(error_log).to be_truthy
			
			# Verify server is still working by sending a new request:
			stream = endpoint.connect
			message = {id: 1, do: :status}
			write_message(stream, message)
			
			response = read_message(stream)
			expect(response).to have_keys(
				id: be == 1,
				finished: be == true
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
		write_message(stream, message)
		
		# Wait for the message to be processed
		reactor.sleep(0.01)
		
		# Verify a debug warning was logged about ignoring the message:
		debug_log = console_capture.find{|log| log[:severity] == :debug && log[:message] =~ /Ignoring message/}
		expect(debug_log).to be_truthy
		
		# Send a valid message to confirm the server is still working:
		valid_message = {id: 3, do: :register, state: {process_id: ::Process.pid}}
		write_message(stream, valid_message)
		
		# Read the response to the valid message:
		response = read_message(stream)
		
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
		write_message(stream, stale_message)
		
		# Send a valid message:
		valid_message = {id: 7, do: :register, state: {process_id: ::Process.pid}}
		write_message(stream, valid_message)
		
		# We should only get ONE response - for the valid message.
		# Not an error response for the stale message.
		response = read_message(stream)
		
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
