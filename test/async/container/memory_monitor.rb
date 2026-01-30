# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/supervisor/memory_monitor"
require "async/container/supervisor/a_monitor"

require "sus/fixtures/console/captured_logger"

describe Async::Container::Supervisor::MemoryMonitor do
	include Sus::Fixtures::Console::CapturedLogger
	
	let(:monitor) {subject.new(interval: 1, memory_sample: {duration: 1, timeout: 5})}
	it_behaves_like Async::Container::Supervisor::AMonitor
	
	# Mock connection object for testing
	let(:mock_connection) do
		Object.new.tap do |connection|
			def connection.state
				@state ||= {}
			end
		end
	end
	
	with "#register" do
		it "adds process to cluster when registering first connection" do
			process_id = 12345
			mock_connection.state[:process_id] = process_id
			
			expect(monitor.cluster).to receive(:add).with(process_id)
			
			monitor.register(mock_connection)
			
			# With mutex, operation happens immediately
			expect(monitor.cluster.processes.keys).to be(:include?, process_id)
		end
		
		it "does not add process to cluster when connection already exists" do
			process_id = 12345
			mock_connection.state[:process_id] = process_id
			
			# Register first connection
			monitor.register(mock_connection)
			
			# Verify process was added
			expect(monitor.cluster.processes.keys).to be(:include?, process_id)
			
			# Count how many processes are in cluster before second registration
			process_count_before = monitor.cluster.processes.size
			
			# Register second connection to same process - should not add again
			mock_connection2 = Object.new.tap do |conn|
				def conn.state
					@state ||= {process_id: 12345}
				end
			end
			
			monitor.register(mock_connection2)
			
			# Process count should not increase (no new add operation)
			process_count_after = monitor.cluster.processes.size
			expect(process_count_after).to be == process_count_before
		end
		
		it "handles connection without process_id gracefully" do
			mock_connection.state.clear
			
			# Count processes before
			process_count_before = monitor.cluster.processes.size
			
			# Should not raise an error or call add
			monitor.register(mock_connection)
			
			# Process count should not change
			process_count_after = monitor.cluster.processes.size
			expect(process_count_after).to be == process_count_before
		end
	end
	
	with "#remove" do
		it "removes process from cluster when removing last connection" do
			process_id = 12345
			mock_connection.state[:process_id] = process_id
			
			# Register first
			monitor.register(mock_connection)
			
			# Verify process was added
			expect(monitor.cluster.processes.keys).to be(:include?, process_id)
			
			# Remove
			expect(monitor.cluster).to receive(:remove).with(process_id)
			
			monitor.remove(mock_connection)
			
			# With mutex, operation happens immediately
			expect(monitor.cluster.processes.keys).not.to be(:include?, process_id)
		end
		
		it "does not remove process from cluster when other connections exist" do
			process_id = 12345
			mock_connection.state[:process_id] = process_id
			
			# Register first connection
			monitor.register(mock_connection)
			
			# Register second connection
			mock_connection2 = Object.new.tap do |conn|
				def conn.state
					@state ||= {process_id: 12345}
				end
			end
			monitor.register(mock_connection2)
			
			# Verify process is still in cluster
			expect(monitor.cluster.processes.keys).to be(:include?, process_id)
			
			# Count processes before removal
			process_count_before = monitor.cluster.processes.size
			
			# Remove first connection - should not remove (other connection exists)
			monitor.remove(mock_connection)
			
			# Process count should not decrease
			process_count_after = monitor.cluster.processes.size
			expect(process_count_after).to be == process_count_before
			
			# Process should still be in cluster
			expect(monitor.cluster.processes.keys).to be(:include?, process_id)
		end
		
		it "handles connection without process_id gracefully" do
			mock_connection.state.clear
			
			# Count processes before
			process_count_before = monitor.cluster.processes.size
			
			# Should not raise an error or call remove
			monitor.remove(mock_connection)
			
			# Process count should not change
			process_count_after = monitor.cluster.processes.size
			expect(process_count_after).to be == process_count_before
		end
	end
	
	with "mutex serialization" do
		include Sus::Fixtures::Async::SchedulerContext
		
		it "serializes register operations with cluster check" do
			process_id = 12345
			mock_connection.state[:process_id] = process_id
			
			# Register connection - with mutex, operation happens immediately
			monitor.register(mock_connection)
			
			# Verify process was added immediately
			expect(monitor.cluster.processes.keys).to be(:include?, process_id)
		end
		
		it "serializes multiple register/remove operations" do
			process_id1 = 11111
			process_id2 = 22222
			
			conn1 = Object.new.tap do |c|
				def c.state
					@state ||= {process_id: 11111}
				end
			end
			conn2 = Object.new.tap do |c|
				def c.state
					@state ||= {process_id: 22222}
				end
			end
			
			# Register both connections - operations happen immediately with mutex
			monitor.register(conn1)
			monitor.register(conn2)
			
			# Verify both processes were added
			expect(monitor.cluster.processes.keys).to be(:include?, process_id1)
			expect(monitor.cluster.processes.keys).to be(:include?, process_id2)
			
			# Remove first connection
			monitor.remove(conn1)
			
			# Verify operations were executed: process_id2 should still be there, process_id1 should be removed
			expect(monitor.cluster.processes.keys).to be(:include?, process_id2)
			expect(monitor.cluster.processes.keys).not.to be(:include?, process_id1)
		end
	end
	
	with "#memory_leak_detected" do
		let(:monitor_without_sample) {subject.new(interval: 1)}
		
		it "kills process when memory leak is detected" do
			process_id = 12345
			mock_monitor = Object.new
			
			expect(Process).to receive(:kill).with(:INT, process_id)
			
			result = monitor_without_sample.memory_leak_detected(process_id, mock_monitor)
			
			expect(result).to be == true
		end
		
		it "handles already-dead process gracefully" do
			process_id = 99999 # Non-existent process
			mock_monitor = Object.new
			
			expect(Process).to receive(:kill).with(:INT, process_id).and_raise(Errno::ESRCH)
			
			# Should not raise an error
			result = monitor_without_sample.memory_leak_detected(process_id, mock_monitor)
			
			expect(result).to be == true
		end
		
		it "captures memory sample when enabled" do
			process_id = 12345
			mock_monitor = Object.new
			mock_connection.state[:process_id] = process_id
			
			# Register connection
			monitor.register(mock_connection)
			
			# Mock the connection call
			expect(mock_connection).to receive(:call).with(
				do: :memory_sample,
				duration: 1,
				timeout: 5
			).and_return({data: "sample data"})
			
			expect(Process).to receive(:kill).with(:INT, process_id)
			
			monitor.memory_leak_detected(process_id, mock_monitor)
		end
	end
	
	with "#run" do
		include Sus::Fixtures::Async::SchedulerContext
		
		it "can run the monitor" do
			task = monitor.run
			expect(task).to be(:running?)
		ensure
			task&.stop
		end
		
		it "can handle failures" do
			checked = Async::Promise.new
			
			# The monitor should continue running even if check! raises errors
			# Loop.run handles errors internally, so we just verify the task stays running
			expect(monitor.cluster).to receive(:check!){checked.resolve(true); raise Errno::ESRCH}
			
			task = monitor.run
			expect(task).to be(:running?)
			
			# Wait for iterations - Loop.run catches errors and continues
			checked.wait
			
			# Task should still be running despite errors
			# (Loop.run catches exceptions and logs them, then continues)
			expect(task).to be(:running?)
		ensure
			task&.stop
		end
		
		it "serializes register operations with cluster check" do
			process_id = 12345
			mock_connection.state[:process_id] = process_id
			
			# Register connection - with mutex, operation happens immediately
			monitor.register(mock_connection)
			
			# Verify process was added immediately (mutex ensures this happens synchronously)
			expect(monitor.cluster.processes.keys).to be(:include?, process_id)
			
			# Start the monitor - the mutex ensures check! runs after register completes
			task = monitor.run
			
			# Give it a moment to run
			reactor.sleep(0.1)
			
			# Process should still be in cluster (check! doesn't remove it unless there's a leak)
			expect(monitor.cluster.processes.keys).to be(:include?, process_id)
		ensure
			task&.stop
		end
	end
end

