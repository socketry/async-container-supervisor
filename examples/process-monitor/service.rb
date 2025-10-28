#!/usr/bin/env async-service
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/supervisor"

class WorkerService < Async::Service::Generic
	def setup(container)
		super
		
		container.run(name: self.class.name, count: 4, restart: true, health_check_timeout: 2) do |instance|
			Async do
				if @environment.implements?(Async::Container::Supervisor::Supervised)
					@evaluator.make_supervised_worker(instance).run
				end
				
				start_time = Time.now
				
				instance.ready!
				
				# Simulate some CPU and memory activity
				counter = 0
				chunks = []
				while true
					# Do some work
					counter += 1
					if counter % 10 == 0
						chunks << " " * 1024 * 1024 * rand(5)
					end
					
					# Simulate CPU usage
					(1..1000).each {|i| Math.sqrt(i)}
					
					sleep 1
					instance.ready!
					
					uptime = Time.now - start_time
					instance.name = "Worker running for #{uptime.to_i} seconds (counter: #{counter})"
				end
			ensure
				Console.info(self, "Exiting...")
			end
		end
	end	
end

service "worker" do
	service_class WorkerService
	
	include Async::Container::Supervisor::Supervised
end

service "supervisor" do
	include Async::Container::Supervisor::Environment
	
	monitors do
		[
			# Monitor process metrics every 10 seconds
			Async::Container::Supervisor::ProcessMonitor.new(interval: 10),
			
			# Also monitor memory and restart workers if they exceed 500MB
			Async::Container::Supervisor::MemoryMonitor.new(
				interval: 5,
				maximum_size_limit: 1024 * 1024 * 500
			)
		]
	end
end

