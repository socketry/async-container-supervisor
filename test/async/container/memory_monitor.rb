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
	
	with "#run" do
		include Sus::Fixtures::Async::SchedulerContext
		
		it "can run the monitor" do
			task = monitor.run
			expect(task).to be(:running?)
		end
		
		it "can handle failures" do
			expect(monitor.cluster).to receive(:check!).and_raise(Errno::ESRCH)
			
			task = monitor.run
			expect(task).to be(:running?)
			
			sleep 1
			
			expect(task).to be(:running?)
		end
	end
end

