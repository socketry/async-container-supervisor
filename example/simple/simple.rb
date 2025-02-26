#!/usr/bin/env async-service

require "async/container/supervisor"

class SleepService < Async::Service::Generic
	def setup(container)
		super
		
		container.run(name: self.class.name, count: 4, restart: true, health_check_timeout: 2) do |instance|
			Async do
				client = Async::Container::Supervisor::Client.new(instance, @evaluator.supervisor_endpoint)
				client.run
				
				start_time = Time.now
				
				instance.ready!
				
				chunks = []
				while true
					chunks << " " * 1024 * 1024 * rand(10) 
					sleep 1
					instance.ready!
					
					uptime = Time.now - start_time
					instance.name = "Sleeping for #{uptime.to_i} seconds..."
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
		[Async::Container::Supervisor::MemoryMonitor.new(interval: 1, limit: 1024 * 1024 * 100)]
	end
end
