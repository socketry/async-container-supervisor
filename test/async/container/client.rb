# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/supervisor/a_server"
require "sus/fixtures/console/captured_logger"

describe Async::Container::Supervisor::Client do
	include Async::Container::Supervisor::AServer
	include Sus::Fixtures::Console::CapturedLogger
	
	let(:client) {subject.new(endpoint: endpoint)}
	
	with "#connect" do
		it "can connect to a server" do
			client.connect do |connection|
				expect(connection).to be_a(Async::Container::Supervisor::Connection)
			end
		end
	end
	
	with "#run" do
		it "can run the client" do
			connected = Async::Promise.new
			expect(client).to receive(:connected!) {|connection| connected.resolve(true)}
			
			client_task = client.run
			
			expect(client_task).to be(:transient?)
			expect(connected.wait).to be == true
			
			client_task.stop
		end
		
		it "does not leak fibers when connected! creates tasks and reconnection occurs" do
			state = Thread::Queue.new
			
			mock(client) do |mock|
				mock.replace(:connected!) do
					state << :connected
					
					Async do
						sleep
					ensure
						state << :disconnected
					end
				end
			end
			
			client_task = client.run
			expect(state.pop).to be == :connected
			
			# Interrupt the supervisor:
			restart_supervisor
			
			expect(state.pop).to be == :disconnected
			expect(state.pop).to be == :connected
		end
	end
end
