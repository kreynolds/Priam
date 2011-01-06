module Priam
	class PriamError < Exception; end

	# This will wrap every method going to the connection in a log line
	def self.method_missing(method, *args, &block)
		retries = Connection.connection_configuration(RAILS_ENV)[:retries] || 5
		retries.times do
			begin
				res = nil
				Logger.log method, *args do
					res = Connection.connection.send(method, *args)
				end
				return res
			rescue CassandraThrift::InvalidRequestException
				raise $!
			rescue
				Rails.logger.warn "#{method} Error: #{$!.class}: #{$!.to_s}"
			end
		end
		
		raise PriamError, "Unable to execute #{method} after #{retries} attempts"
	end
	
	class Connection
		def self.connection_configuration_path
			File.join(RAILS_ROOT, "config", "priam.yml")
		end

		def self.connection_configuration(environment)
			@connection_configuration ||= YAML.load(File.read(connection_configuration_path)).with_indifferent_access
			@connection_configuration[environment] || {}
		end

		def self.establish_connection(config = connection_configuration(RAILS_ENV))
			case(adapter = config[:adapter].to_s)
			when "", "Cassandra", "cassandra"
				raise("no keyspace in the configuration file") unless config[:keyspace]
				host = config[:host] || '127.0.0.1:9160'
				host = [host] if !host.kind_of?(Array)
				timeout = config[:timeout] || 5
				transport = case config[:transport]
					when 'framed'
						Thrift::FramedTransport
					when 'buffered'
						Thrift::BufferedTransport
					else
						Thrift::FramedTransport
				end
				Logger.log "connect", "hosts => #{host.join(",")}, transport => #{transport}, timeout => #{timeout}" do
					@connection = Cassandra.new(config[:keyspace], host, :timeouts => Hash.new(timeout), :transport_wrapper => transport)
				end
			else
				raise PriamError, "Invalid Priam adapter: #{config[:adapter]}"
			end
		end

		def self.connection
			@connection || establish_connection
		end

		def connection
			self.class.connection
		end

		def to_s
			inspect
		end
	end	
end
