# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/supervisor/connection"
require "sus/fixtures/async/scheduler_context"
require "stringio"
require "msgpack"

class TrueObject
	def as_json
		true
	end
end

describe Async::Container::Supervisor::MessageWrapper do
	let(:stream) {StringIO.new}
	let(:message_wrapper) {Async::Container::Supervisor::MessageWrapper.new(stream)}
	
	def write_message(message)
		message_wrapper.write(message)
		stream.rewind
	end
	
	def read_message
		message_wrapper.read
	end
	
	with "write and read" do
		it "normalizes without infinite loop" do
			Integer.define_method(:as_json) do
				self
			end
			
			write_message({id: 1, do: :test})
			
			message = read_message
			expect(message[:id]).to be == 1
		ensure
			Integer.send(:remove_method, :as_json)
		end
		
		it "handles simple strings" do
			write_message({message: "hello world"})
			
			result = read_message
			expect(result[:message]).to be == "hello world"
		end
		
		it "handles integers" do
			write_message({count: 42, negative: -10})
			
			result = read_message
			expect(result[:count]).to be == 42
			expect(result[:negative]).to be == -10
		end
		
		it "handles floats" do
			write_message({pi: 3.14159, negative: -2.5})
			
			result = read_message
			expect(result[:pi]).to be == 3.14159
			expect(result[:negative]).to be == -2.5
		end
		
		it "handles boolean values" do
			write_message({success: true, failed: false})
			
			result = read_message
			expect(result[:success]).to be == true
			expect(result[:failed]).to be == false
		end
		
		it "handles nil values" do
			write_message({empty: nil})
			
			result = read_message
			expect(result[:empty]).to be_nil
		end
		
		it "handles arrays" do
			write_message({items: [1, 2, 3, "four", true]})
			
			result = read_message
			expect(result[:items]).to be == [1, 2, 3, "four", true]
		end
		
		it "handles nested hashes" do
			write_message({
				user: {
					name: "Alice",
					details: {
						age: 30,
						active: true
					}
				}
			})
			
			result = read_message
			expect(result[:user][:name]).to be == "Alice"
			expect(result[:user][:details][:age]).to be == 30
			expect(result[:user][:details][:active]).to be == true
		end
		
		it "handles nested arrays" do
			write_message({matrix: [[1, 2], [3, 4], [5, 6]]})
			
			result = read_message
			expect(result[:matrix]).to be == [[1, 2], [3, 4], [5, 6]]
		end
		
		it "handles symbols" do
			write_message({action: :start, status: :success})
			
			result = read_message
			expect(result[:action]).to be == :start
			expect(result[:status]).to be == :success
		end
		
		it "handles empty hash" do
			write_message({})
			
			result = read_message
			expect(result).to be == {}
		end
		
		it "handles empty array" do
			write_message({items: []})
			
			result = read_message
			expect(result[:items]).to be == []
		end
	end
	
	with "Time handling" do
		it "serializes and deserializes Time objects" do
			time = Time.now
			write_message({timestamp: time})
			
			result = read_message
			expect(result[:timestamp]).to be_within(0.001).of(time)
		end
		
		it "handles Time in nested structures" do
			time = Time.now
			write_message({
				event: {
					name: "test",
					occurred_at: time
				}
			})
			
			result = read_message
			expect(result[:event][:occurred_at]).to be_within(0.001).of(time)
		end
	end
	
	with "Class handling" do
		it "serializes class names" do
			write_message({type: String})
			
			result = read_message
			expect(result[:type]).to be == "String"
		end
		
		it "handles multiple classes" do
			write_message({types: [String, Integer, Array]})
			
			result = read_message
			expect(result[:types]).to be == ["String", "Integer", "Array"]
		end
	end
	
	with "Exception handling" do
		it "serializes and deserializes RuntimeError" do
			error = RuntimeError.new("Something went wrong")
			error.set_backtrace(["line1", "line2"])
			
			write_message({error: error})
			
			result = read_message
			expect(result[:error]).to be_a(RuntimeError)
			expect(result[:error].message).to be == "Something went wrong"
			expect(result[:error].backtrace).to be == ["line1", "line2"]
		end
		
		it "handles StandardError" do
			error = StandardError.new("Standard error")
			write_message({error: error})
			
			result = read_message
			expect(result[:error]).to be_a(StandardError)
			expect(result[:error].message).to be == "Standard error"
		end
		
		it "handles ArgumentError" do
			error = ArgumentError.new("Invalid argument")
			write_message({error: error})
			
			result = read_message
			expect(result[:error]).to be_a(ArgumentError)
			expect(result[:error].message).to be == "Invalid argument"
		end
	end
	
	with "normalize method" do
		it "normalizes objects with as_json method" do
			obj = TrueObject.new
			write_message({custom: obj})
			
			result = read_message
			expect(result[:custom]).to be == true
		end
		
		it "normalizes arrays of objects with as_json" do
			write_message({items: [TrueObject.new, TrueObject.new]})
			
			result = read_message
			expect(result[:items]).to be == [true, true]
		end
		
		it "normalizes nested objects with as_json" do
			write_message({
				data: {
					flag: TrueObject.new,
					nested: {
						another: TrueObject.new
					}
				}
			})
			
			result = read_message
			expect(result[:data][:flag]).to be == true
			expect(result[:data][:nested][:another]).to be == true
		end
	end
	
	with "complex messages" do
		it "handles complex nested structures" do
			write_message({
				id: 123,
				action: :process,
				data: {
					items: [1, 2, 3],
					metadata: {
						timestamp: Time.now,
						type: String
					}
				},
				flags: {
					active: true,
					debug: false
				}
			})
			
			result = read_message
			expect(result[:id]).to be == 123
			expect(result[:action]).to be == :process
			expect(result[:data][:items]).to be == [1, 2, 3]
			expect(result[:flags][:active]).to be == true
		end
		
		it "handles large arrays" do
			large_array = (1..1000).to_a
			write_message({data: large_array})
			
			result = read_message
			expect(result[:data]).to be == large_array
		end
		
		it "handles deeply nested structures" do
			deep = {level1: {level2: {level3: {level4: {level5: "deep"}}}}}
			write_message(deep)
			
			result = read_message
			expect(result[:level1][:level2][:level3][:level4][:level5]).to be == "deep"
		end
	end
	
	with "edge cases" do
		it "handles empty string" do
			write_message({text: ""})
			
			result = read_message
			expect(result[:text]).to be == ""
		end
		
		it "handles zero values" do
			write_message({count: 0, amount: 0.0})
			
			result = read_message
			expect(result[:count]).to be == 0
			expect(result[:amount]).to be == 0.0
		end
		
		it "handles unicode strings" do
			write_message({text: "Hello 世界 🌍"})
			
			result = read_message
			expect(result[:text]).to be == "Hello 世界 🌍"
		end
		
		it "handles special characters" do
			write_message({text: "Line1\nLine2\tTabbed"})
			
			result = read_message
			expect(result[:text]).to be == "Line1\nLine2\tTabbed"
		end
	end
end
