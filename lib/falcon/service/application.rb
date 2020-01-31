# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative 'proxy'

require 'async/http/endpoint'
require 'async/io/shared_endpoint'

module Falcon
	module Service
		class Application < Proxy
			def initialize(environment)
				super
				
				@bound_endpoint = nil
			end
			
			def middleware
				@evaluator.middleware
			end
			
			def preload!
				if scripts = @evaluator.preload
					scripts.each do |path|
						Async.logger.info(self) {"Preloading #{path}..."}
						full_path = File.expand_path(path, self.root)
						load(full_path)
					end
				end
			end
			
			def start
				Async.logger.info(self) {"Binding to #{self.endpoint}..."}
				
				@bound_endpoint = Async::Reactor.run do
					Async::IO::SharedEndpoint.bound(self.endpoint)
				end.wait
				
				preload!
				
				super
			end
			
			def setup(container)
				container.run(name: self.name, restart: true) do |instance|
					Async(logger: logger) do |task|
						Async.logger.info(self) {"Starting application server for #{self.root}..."}
						
						server = Server.new(self.middleware, @bound_endpoint, self.protocol, self.scheme)
						
						server.run
						
						instance.ready!
						
						task.children.each(&:wait)
					end
				end
				
				super
			end
			
			def stop
				@bound_endpoint&.close
				@bound_endpoint = nil
				
				super
			end
		end
	end
end
