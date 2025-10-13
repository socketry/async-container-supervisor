#!/usr/bin/env async-service
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/supervisor"

class SleepService < Async::Service::Generic
	def setup(container)
		super
		
		container.run(name: self.class.name, count: 4, restart: true, health_check_timeout: 2) do |instance|
			Async do
				if @environment.implements?(Async::Container::Supervisor::Supervised)
					@evaluator.make_supervised_worker(instance).run
				end
				
				start_time = Time.now
				
				instance.ready!
				
				chunks = []
				while true
					Console.info(self, "Leaking memory...")
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
	
	include Async::Container::Supervisor::Supervised
end

service "supervisor" do
	include Async::Container::Supervisor::Environment
	
	monitors do
		[Async::Container::Supervisor::MemoryMonitor.new(
			# The interval at which to check for memory leaks.
			interval: 1,
			# The total size limit of all processes:
			maximum_size_limit: 1024 * 1024 * 40, # 40 MB
		)]
	end
end
