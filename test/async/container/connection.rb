# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/supervisor/connection"
require "sus/fixtures/async/scheduler_context"
require "stringio"

class TestTarget
	def initialize(&block)
		@block = block
	end
	
	def dispatch(call)
		@block.call(call)
	end
end

class SlowWriteStringIO < StringIO
	def write(data)
		super(data)
		sleep(1) # Simulate a slow write
	end
end

describe Async::Container::Supervisor::Connection do
	let(:stream) {StringIO.new}
	let(:connection) {Async::Container::Supervisor::Connection.new(stream)}
	
	with "dispatch" do
		it "handles failed writes when dispatching a call" do
			stream.write(JSON.dump({id: 1, do: :test}) << "\n")
			stream.rewind
			
			expect(stream).to receive(:write).and_raise(IOError, "Write error")
			
			target = TestTarget.new do |call|
				Async do
					call.push(status: "working")
					sleep(0) # Yield back to the dispatch to allow the write to fail.
					call.finish(status: "done")
				end
			end
			
			connection.run(target)
			
			expect(connection.calls).to be(:empty?)
		end
		
		it "closes the queue when the connection fails" do
			stream.write(JSON.dump({id: 1, do: :test}) << "\n")
			stream.rewind
			
			expect(stream).to receive(:write).and_raise(IOError, "Write error")
			
			task = nil
			
			target = TestTarget.new do |call|
				task = Async do
					while true
						call.push(status: "working")
						sleep(0.001) # Loop forever (until the queue is closed).
					end
				end
			end
			
			connection.run(target)
			
			expect(connection.calls).to be(:empty?)
			expect(task).to be(:failed?)
			expect{task.wait}.to raise_exception(ClosedQueueError)
		end
	end
	
	with "call" do
		include Sus::Fixtures::Async::SchedulerContext
		
		it "handles failed writes when making a call" do
			expect(stream).to receive(:write).and_raise(IOError, "Write error")
			
			expect do
				connection.call(do: :test)
			end.to raise_exception(IOError, message: be =~ /Write error/)
			
			expect(connection.calls).to be(:empty?)
		end
	end
	
	with subject::Call do
		let(:test_call) {Async::Container::Supervisor::Connection::Call.new(connection, 1, {do: :test, data: "value"})}
		
		it "can serialize call to JSON" do
			json = test_call.to_json
			parsed = JSON.parse(json)
			
			expect(parsed).to have_keys(
				"do" => be == "test",
				"data" => be == "value"
			)
		end
		
		it "can get call message via as_json" do
			expect(test_call.as_json).to have_keys(
				do: be == :test,
				data: be == "value"
			)
		end
		
		it "can iterate over call responses with each" do
			# Push some responses
			test_call.push(status: "working")
			test_call.push(status: "done")
			test_call.close
			
			responses = []
			test_call.each do |response|
				responses << response
			end
			
			expect(responses.size).to be == 2
			expect(responses[0]).to have_keys(status: be == "working")
			expect(responses[1]).to have_keys(status: be == "done")
		end
		
		it "can fail a call" do
			test_call.fail(error: "Something went wrong")
			
			response = test_call.pop
			expect(response).to have_keys(
				id: be == 1,
				finished: be == true,
				failed: be == true,
				error: be == "Something went wrong"
			)
			
			expect(test_call.closed?).to be == true
		end
		
		it "can access message via []" do
			expect(test_call[:do]).to be == :test
			expect(test_call[:data]).to be == "value"
		end
		
		it "reports closed? correctly" do
			expect(test_call.closed?).to be == false
			
			test_call.finish
			
			expect(test_call.closed?).to be == true
		end
	end
	
	it "writes JSON with newline" do
		connection.write(id: 1, do: :test)
		
		stream.rewind
		output = stream.read
		
		# Check it's valid JSON with a newline
		expect(output[-1]).to be == "\n"
		
		parsed = JSON.parse(output.chomp)
		expect(parsed).to have_keys(
			"id" => be == 1,
			"do" => be == "test"
		)
	end
	
	it "parses JSON lines" do
		stream.string = JSON.dump({id: 1, do: "test"}) << "\n"
		stream.rewind
		
		message = connection.read
		
		# Connection.read uses symbolize_names: true (keys are symbols, values are as-is)
		expect(message).to have_keys(
			id: be == 1,
			do: be == "test"
		)
	end
	
	it "returns nil when stream is closed" do
		stream.string = ""
		stream.rewind
		
		message = connection.read
		
		expect(message).to be_nil
	end
	
	it "increments id by 2" do
		first_id = connection.next_id
		second_id = connection.next_id
		
		expect(second_id).to be == first_id + 2
	end
	
	with "#close" do
		it "closes all pending calls" do
			call1 = Async::Container::Supervisor::Connection::Call.new(connection, 1, {do: :test})
			call2 = Async::Container::Supervisor::Connection::Call.new(connection, 2, {do: :test})
			
			connection.calls[1] = call1
			connection.calls[2] = call2
			
			connection.close
			
			expect(call1.closed?).to be == true
			expect(call2.closed?).to be == true
			expect(connection.calls).to be(:empty?)
		end
		
		it "closes the stream" do
			connection.close
			expect(stream).to be(:closed?)
		end
		
		it "closes while writing" do
			slow_connection = Async::Container::Supervisor::Connection.new(SlowWriteStringIO.new)
			
			Async do
				Async do |task|
					slow_connection.write(id: 1, do: :test)
				end
				
				Async do |task|
					slow_connection.close
				end
			end
		end
	end
end
