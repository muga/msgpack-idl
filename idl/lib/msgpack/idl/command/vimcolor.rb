#
# VimColor for Ruby
#
# Copyright (c) 2008-2011 FURUHASHI Sadayuki
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
#

class VimColor
	VIM_COMMAND = "vim"
	VIM_OPTIONS = %w[-R -X -Z -i NONE -u NONE -N]
	VIM_PRESET  = ["+set nomodeline", '+set expandtab'] # +set shiftwidth
	VIM_POSTSET = [":let b:is_bash=1", ":filetype on"]
	VIM_MARK_SCRIPT = File.join(File.dirname(__FILE__), 'vimcolor', 'mark.vim')
	VIM_UNESCAPE = {'&l' => '<', '&g' => '>', '&a' => '&'}

	def initialize(command=nil, options=nil, preset=nil, postset=nil)
		require 'tempfile'
		@command = VIM_COMMAND.dup
		@options = VIM_OPTIONS + (options || [])
		@preset  = VIM_PRESET  + (preset  || [])
		@postset = VIM_POSTSET + (postset || [])
	end

	attr_accessor :command, :options, :preset, :postset

	def run_file(path, options, formatter_class, *formatter_args)
		preset = @preset.dup
		postset = @postset.dup

		if formatter_class.class == Symbol
			formatter_class = self.class.const_get("Format_#{formatter_class}")
		end

		if options.is_a? Hash
			if options.include? :filetype
				postset.unshift(":set filetype=#{options[:filetype]}")
			end
			if options.include? :encoding
				preset.unshift("+set encoding=#{options[:encoding]}")
			end
		else
			postset.unshift(":set filetype=#{options}")
		end

		vimout = nil
		tmp_stream = Tempfile.new('ruby-vimcolor')
		begin
			tmp_path = tmp_stream.path
			tmp_stream.puts <<SCRIPT
:syntax on
#{postset.join("\n")}
:source #{VIM_MARK_SCRIPT}
:write! #{tmp_path}
:qall!

SCRIPT
			tmp_stream.flush
			pid = Process.fork {
				STDIN.reopen "/dev/null"
				STDOUT.reopen "/dev/null", "a"
				STDERR.reopen "/dev/null", "a"
				args = []
				args.concat @options
				args.concat ['-s', tmp_path]
				args.push path
				args.concat preset
				exec(@command, *args)
				exit 127
			}
			Process.waitpid(pid)
			tmp_stream.seek(0)
			vimout = tmp_stream.read
		ensure
			tmp_stream.close
		end

		require 'strscan'
		s = StringScanner.new(vimout)

		formatter = formatter_class.new(*formatter_args)
		while s.scan_until(/(.*?)>(.*?)>(.*?)<\2</m)
			formatter.push('', s[1]) unless s[1].empty?
			type = s[2]
			text = s[3]
			text.gsub!(/&[agl]/) do
				VIM_UNESCAPE[$&]
			end
			formatter.push(type, text)
		end
		formatter.result
	end


	def run_stream(stream, options, formatter_class, *formatter_args)
		tmp_in = Tempfile.new('ruby-vimcolor-input')
		begin
			tmp_in.write(stream.read)
			tmp_in.flush
			run_file(tmp_in.path, options, formatter_class, *formatter_args)
		ensure
			tmp_in.close
		end
	end


	def run(str, options, formatter_class, *formatter_args)
		tmp_in = Tempfile.new('ruby-vimcolor-input')
		begin
			tmp_in.write(str)
			tmp_in.flush
			run_file(tmp_in.path, options, formatter_class, *formatter_args)
		ensure
			tmp_in.close
		end
	end
end



class VimColor

	class Format_array
		def initialize
			@result = []
		end
		def push(type, text)
			@result.push [type, text]
		end
		attr_reader :result
	end


	class Format_xml
		def initialize
			@result = ''
		end
		def push(type, text)
			VimColor._escape_xml!(text)
			type = 'Normal' if type.empty?
			@result << %[<#{type}>#{text}</#{type}>]
		end
		attr_reader :result
	end


	class Format_html
		def initialize(class_prefix = 'syn')
			@result = ''
			@prefix = class_prefix
		end
		def push(type, text)
			VimColor._escape_xml!(text)
			if type.empty?
				@result << text
			else
				@result << %[<span class="#{@prefix}#{type}">#{text}</span>]
			end
		end
		attr_reader :result
	end


	def self._escape_xml!(text)
		text.gsub!("&", "&amp;")
		text.gsub!("<", "&lt;")
		text.gsub!(">", "&gt;")
		text.gsub!("'", "&#39;")
		text.gsub!('"', "&quot;")
		text
	end


	class Format_ansi
		AnsiCodes = {
			:normal        =>  0,
			:reset         =>  0,
			:bold          =>  1,
			:dark          =>  2,
			:italic        =>  3,
			:underline     =>  4,
			:blink         =>  5,
			:rapid_blink   =>  6,
			:negative      =>  7,
			:concealed     =>  8,
			:strikethrough =>  9,
			:black         => 30,
			:red           => 31,
			:green         => 32,
			:yellow        => 33,
			:blue          => 34,
			:magenta       => 35,
			:cyan          => 36,
			:white         => 37,
			:on_black      => 40,
			:on_red        => 41,
			:on_green      => 42,
			:on_yellow     => 43,
			:on_blue       => 44,
			:on_magenta    => 45,
			:on_cyan       => 46,
			:on_white      => 47,
		}
		def initialize(colors = {})
			@result = ''
			@colors = Hash.new([])
			@colors.merge!({
				'Comment'    => [ :cyan ],
				'Constant'   => [ :red ],
				'Identifier' => [ :green  ],
				'Statement'  => [ :yellow ],
				'PreProc'    => [ :magenta ],
				'Type'       => [ :green ],
				'Special'    => [ :magenta ],
				'Underlined' => [ :underline ],
				'Error'      => [ :red ],
				'Todo'       => [ :black, :on_yellow ],
			})
			@colors.merge!(colors)
		end
		def push(type, text)
			seq = ''
			codes = @colors[type].dup
			codes.unshift(:reset)
			codes.each {|c|
				num = AnsiCodes[c]
				seq << "\e[#{num}m" if num
			}
			@result << seq << text
		end
		def result
			@result << "\e[0m"
			@result
		end
	end

end

