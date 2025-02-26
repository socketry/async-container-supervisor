# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Async
	module Container
		module Supervisor
			module Monitor
				class PeriodicMonitor
					def initialize(interval: 1, &block)
						@interval = interval
						@block = block
					end
					
					def register(wrapper, state)
					end
					
					def remove(wrapper, state)
					end
					
					def run
						Async do
							while true
								@block.call
								
								sleep(@interval)
							end
						end
					end
				end
			end
		end
	end
end
