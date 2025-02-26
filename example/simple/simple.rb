#!/usr/bin/env async-service

require "async/container/supervisor"

class SleepService < Async::Service::Generic
	def setup(container)
		super
		
		container.run(count: 1, restart: true, health_check_timeout: 2) do |instance|
			Async do
				client = Async::Container::Supervisor::Client.new(instance, @evaluator.supervisor_endpoint)
				client.run
				
				instance.ready!
				
				chunks = []
				while true
					Console.info(self, "Allocating memory...")
					# Allocate 10MB of memory every second:
					chunks << " " * 1024 * 1024
					sleep 0.1
					instance.ready!
				end
			ensure
				Console.info(self, "Exiting...")
			end
		end
	end	
end

service "sleep" do
	service_class SleepService
	
	supervisor_endpoint {Async::Container::Supervisor.endpoint}
end

service "supervisor" do
	include Async::Container::Supervisor::Environment
	
	monitors do
		[Async::Container::Supervisor::Monitor::MemoryMonitor.new(interval: 1, limit: 1024 * 1024 * 100)]
	end
end
