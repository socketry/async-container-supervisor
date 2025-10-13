#!/usr/bin/env async-service
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/supervisor"

class SleepService < Async::Service::Generic
	def setup(container)
		super
		
		container.run(name: self.class.name, count: 1, restart: true, health_check_timeout: 2) do |instance|
			Async do
				if @environment.implements?(Async::Container::Supervisor::Supervised)
					@evaluator.make_supervised_worker(instance).run
				end
				
				start_time = Time.now
				
				instance.ready!
				
				sleep # forever
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
end
