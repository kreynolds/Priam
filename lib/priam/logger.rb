module Priam
	class Logger
	   @@colorize_logging = true
      cattr_accessor :colorize_logging, :instance_writer => false

		def self.logger
			Rails.logger
		end
		
		def self.log(method, *args)
			if block_given?
				if logger and logger.level <= 1
					result = nil
					seconds = Benchmark.realtime { result = yield }
					_log(format_args(method, *args), "Priam #{method.to_s.capitalize}", seconds)
					result
				else
					yield
				end
			else
				_log(format_args(method, *args), 0)
				nil
			end
		rescue Exception => e
			# Log message and raise exception.
			message = "#{e.class.name}: #{e.message}: #{method}"
			_log(message, "Priam #{method.to_s.capitalize}", 0)
			raise e
		end

		protected

		def self.format_args(method, *args)
			hash = args.extract_options!
			hash.each_pair do |key, val|
				if val.kind_of?(Hash)
					val.each_pair do |val_key, val_val|
						if val_val.to_s.size > 32
							hash[key][val_key] = "#{val_val.to_s[0...29]}..."
						end
					end
				else
					if val.to_s.size > 32
						hash[key] = "#{val.to_s[0...29]}..."
					end
				end
			end
			msg = [args.inspect[1...-1]]
			msg << hash.inspect if !hash.empty?
			"#{method}(#{msg.join(", ")})"
		end
		
		def self._log(str, name, runtime)
			return unless logger
			if runtime < 1
				runtime = sprintf("%.2fms", runtime*1000)
			else
				runtime = sprintf("%.2fs", runtime)
			end

			logger.debug(
				format_log_entry(
					"#{name || "SR"} (#{runtime})",
					str.gsub(/ +/, " ")
				)
			)
		end

		@@row_even = true
		def self.format_log_entry(message, dump = nil)
			if colorize_logging
				if @@row_even
					@@row_even = false
					message_color, dump_color = "4;36;1", "0;1"
				else
					@@row_even = true
					message_color, dump_color = "4;35;1", "0"
				end

				log_entry = "  \e[#{message_color}m#{message}\e[0m   "
				log_entry << "\e[#{dump_color}m%#{String === dump ? 's' : 'p'}\e[0m" % dump if dump
				log_entry
			else
				"%s  %s" % [message, dump]
			end
		end

		def self.format_error_message(message)
			# bold black on red
			"\e[1;30;41m#{message}\e[0m"
		end

		def self.format_warning_message(message)
			# bold yellow
			"\e[1;33m#{message}\e[0m"
		end

		def self.format_debug_message(message)
			# faint, white on black
			"\e[2;37;40m#{message}\e[0m"
		end
	end
end