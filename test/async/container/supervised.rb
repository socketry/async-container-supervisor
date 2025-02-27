# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/supervisor/a_server"
require "async/container/supervisor/supervised"

class SleepService < Async::Service::Generic
	def setup(container)
		super
		
		container.spawn(name: self.class.name) do |instance|
			Async do
				if @environment.implements?(Async::Container::Supervisor::Supervised)
					@evaluator.make_supervised_worker(instance).run
				end
				
				instance.ready!
				
				sleep
			end
		end
	end	
end

describe Async::Container::Supervisor::Supervised do
	include Async::Container::Supervisor::AServer
	
	let(:state) do
		{process_id: ::Process.pid}
	end
	
	it "can define a supervised service" do
		environment = Async::Service::Environment.build(root: @root) do
			service_class {SimpleService}
			
			include Async::Container::Supervisor::Supervised
		end
		
		evaluator = environment.evaluator
		worker = evaluator.make_supervised_worker(state)
		worker_task = worker.run
		
		sleep(0.001) until registration_monitor.registrations.any?
		
		connection = registration_monitor.registrations.first
		expect(connection.state).to have_keys(
			process_id: be == ::Process.pid
		)
	ensure
		worker_task&.stop
	end
end
