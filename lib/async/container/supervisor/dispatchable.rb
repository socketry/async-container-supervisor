# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "connection"
require_relative "endpoint"

module Async
	module Container
		module Supervisor
			# A mixin for objects that can dispatch calls.
			#
			# Provides automatic method dispatch based on the call's `:do` parameter.
			module Dispatchable
				# Dispatch a call to the appropriate method.
				#
				# Routes calls to methods named `do_#{operation}` based on the call's `:do` parameter.
				#
				# @parameter call [Connection::Call] The call to dispatch.
				def dispatch(call)
					method_name = "do_#{call.message[:do]}"
					self.public_send(method_name, call)
				rescue => error
					Console.error(self, "Error while dispatching call!", exception: error, call: call)
					
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
