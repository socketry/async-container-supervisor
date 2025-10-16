# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "connection"
require_relative "endpoint"

module Async
	module Container
		module Supervisor
			module Dispatchable
				def dispatch(call)
					return unless call.message[:do]
					method_name = "do_#{call.message[:do]}"
					self.public_send(method_name, call)
				rescue => error
					Console.error(self, "Error while dispatching call.", exception: error, call: call)
					
					call.fail(error: {
						class: error.class,
						message: error.message,
						backtrace: error.backtrace,
					})
				end
			end
		end
	end
end
