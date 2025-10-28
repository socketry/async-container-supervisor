# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/supervisor/process_monitor"
require "async/container/supervisor/connection"
require "sus/fixtures/console/captured_logger"

describe Async::Container::Supervisor::ProcessMonitor do
	include Sus::Fixtures::Console::CapturedLogger
	let(:monitor) {subject.new(interval: 10)}
	
	it "has a ppid" do
		expect(monitor.ppid).to be == Process.ppid
	end
	
	it "can capture process metrics" do
		metrics = monitor.metrics
		
		# Should capture at least the current process
		expect(metrics).to be_a(Hash)
		expect(metrics).not.to be(:empty?)
		
		# Check that we have a metric for the current process
		metric = metrics[Process.pid]
		expect(metric).not.to be_nil
		expect(metric.process_id).to be == Process.pid
		expect(metric.command).to be_a(String)
	end
	
	it "can respond to status calls" do
		# Create a mock connection and call
		stream = StringIO.new
		connection = Async::Container::Supervisor::Connection.new(stream)
		
		# Create a mock call
		call_messages = []
		call = Object.new
		def call.push(**message)
			@messages ||= []
			@messages << message
		end
		def call.messages
			@messages || []
		end
		
		monitor.status(call)
		
		expect(call.messages).not.to be(:empty?)
		status = call.messages.first
		expect(status).to have_keys(:process_monitor)
		expect(status[:process_monitor]).to have_keys(:ppid, :metrics)
	end
	
	it "can register and remove connections" do
		stream = StringIO.new
		connection = Async::Container::Supervisor::Connection.new(stream, 0, process_id: Process.pid)
		
		# These should not raise errors
		expect do
			monitor.register(connection)
			monitor.remove(connection)
		end.not.to raise_exception
	end
end

