# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/supervisor/process_monitor"
require "async/container/supervisor/a_monitor"

require "sus/fixtures/console/captured_logger"

describe Async::Container::Supervisor::ProcessMonitor do
	include Sus::Fixtures::Console::CapturedLogger
	
	let(:monitor) {subject.new(interval: 1)}
	it_behaves_like Async::Container::Supervisor::AMonitor
	
	with "#ppid" do
		it "defaults to the current parent process id" do
			expect(monitor.ppid).to be == Process.ppid
		end
	end
	
	with "#run" do
		include Sus::Fixtures::Async::SchedulerContext
		
		it "can run the monitor" do
			task = monitor.run
			expect(task).to be(:running?)
		end
		
		it "can handle failures" do
			expect(monitor).to receive(:metrics).and_raise(Errno::ESRCH)
			
			task = monitor.run
			expect(task).to be(:running?)
			
			sleep 1
			
			expect(task).to be(:running?)
		end
	end
end
