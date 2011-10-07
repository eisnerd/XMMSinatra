require 'rubygems'
require 'superators'

module Enumerable
	def split_by_(f)
	
		last = []
		last_key = nil
		first = true
		
		each do |element|
			key = f.call(element)
			if first
				last_key = key
				first = false
			end

			if last_key == key
				last.push(element)
			else
				yield last_key, last if block_given?
				last_key = key
				last = [element]
			end
		end
		if !last.empty?
			yield last_key, last if block_given?
		end
	end
	
	def split_by
	
		res = []
		last = []
		last_key = nil
		first = true
		
		each do |element|
			key = yield(element)
			if first
				last_key = key
				first = false
			end

			if last_key == key
				last.push element
			else
				res.push [last_key, last]
				last_key = key
				last = [element]
			end
		end
		if !last.empty?
			res.push [last_key, last]
		end
		
		res
	end
	
	def common
		a = nil
		each do |i|
			if a == nil
				if block_given?
					a = yield i
				else
					a = i
				end
			else
				if block_given?
					a &= yield i
				else
					a &= i
				end
			end
		end
		a
	end
end

class Object
	def _? b
		nil? ? b : self
	end
end

class String
	def path_components
		a = self
		res = [] if !block_given?
		loop {
			b, c = File.split(a)
			if block_given?
				yield(c)
			else
				res.push(c)
			end
			break if b == "."
			a = b
		}
		res if !block_given?
	end
end
