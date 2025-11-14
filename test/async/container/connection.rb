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

describe Async::Container::Supervisor::Connection do
	let(:stream) {StringIO.new}
	let(:connection) {Async::Container::Supervisor::Connection.new(stream)}
	let(:message_wrapper) {Async::Container::Supervisor::MessageWrapper.new(stream)}
	
	def write_message(message)
		message_wrapper.write(message)
		stream.rewind
	end
	
	with "dispatch" do
		it "handles failed writes when dispatching a call" do
			write_message({id: 1, do: :test})
			
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
			write_message({id: 1, do: :test})
			
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
	end
end
