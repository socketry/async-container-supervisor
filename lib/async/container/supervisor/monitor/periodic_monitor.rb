# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Async
	module Container
		module Supervisor
			module Monitor
				class PeriodicMonitor
					def initialize(interval: 1)
						@interval = interval
					end
					
					def call
						raise NotImplementedError
					end
					
					def run
						while true
							self.call
							
							sleep(@interval)
						end
					end
				end
			end
		end
	end
end
