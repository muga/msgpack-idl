#
# MessagePack IDL Processor
#
# Copyright (C) 2011 FURUHASHI Sadayuki
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
require 'optparse'

op = OptionParser.new

prog = File.basename($0)
op.banner = <<EOF
Usage: #{prog} [options] -g LANG files...
       #{prog} --list
       #{prog} --example [NAME]
       #{prog} --update LANG [or 'self']

options:
EOF

comment = <<EOF
examples:
  - generate java code from test.msgspec file:
      $ #{prog} -g java test.msgspec
      $ ls gen-java  # generated codes are here

  - generate java code from test.msgspec file to ./out directory:
      $ #{prog} -g java -o out test.msgspec

  - install or update language module
      $ msgpack-idl --update java

  - show examples
      $ msgpack-idl --example # show list of examples
      $ msgpack-idl --example "types"

  - generate sample code
      $ msgpack-idl --update java
      $ msgpack-idl --example sample > sample.msgspec
      $ msgpack-idl -g java sample.msgspec
EOF

(class<<self;self;end).module_eval do
	define_method(:usage) do |msg|
		puts op.to_s
		puts ""
		puts comment
		puts ""
		puts "error: #{msg}" if msg
		exit 1
	end
end

cmd = :generate
conf = {
	:lang => nil,
	:out => nil,
	:show_ast => nil,
	:show_ir => nil,
}

op.on('--example', 'show IDL examples') {
	cmd = :example
}

op.on('--install', 'install or update a language module') {
	cmd = :update
}

op.on('--update', 'install or update a language module') {
	cmd = :update
}

op.on('--list', 'show list of available language modules') {
	cmd = :list
}

op.on_tail('--help', 'show this message') {
	usage nil
}

op.on_tail('--version', 'show version') {
	require 'msgpack/idl/version'
	puts MessagePack::IDL::VERSION
	exit 0
}

op.on('-g', '--lang LANG', 'output language') {|s|
	conf[:lang] = s
}

op.on('-o', '--output DIR', 'output directory (default: ./gen-LANG)') {|s|
	conf[:out] = s
}

op.on('--show-ast', 'show AST for debugging') {
	conf[:show_ast] = true
}

op.on('--show-ir', 'show IR for debugging') {
	conf[:show_ir] = true
}

begin
	op.parse!(ARGV)
rescue
	usage $!.to_s
end

case cmd
when :example
	require 'msgpack/idl/command/example'

	def show_available_examples
		puts "available examples:"
		Example.list.each {|name,summary,code|
			puts "  #{name}#{" "*(10-name.length)}: #{summary}"
		}
	end

	if ARGV.length == 0
		show_available_examples
		exit 1
	elsif ARGV.length > 1
		usage "unknown option: #{ARGV[1]}"
		exit 1
	end

	name = ARGV[0]
	begin
		Example.show(name)
	rescue
		show_available_examples
		puts ""
		puts "error: unknown example name: #{name.dump}"
		exit 1
	end

when :update
	require 'rubygems'
	require 'rubygems/gem_runner'
	require 'rubygems/exceptions'

	if ARGV.length == 0
		usage "language name or 'self' is required."
		exit 1
	elsif ARGV.length > 1
		usage "unknown option: #{ARGV[1]}"
		exit 1
	end

	name = ARGV[0]
	if name == 'self'
		pkg = "msgpack-idl"
	else
		pkg = "msgpack-idl-#{name}"
	end

	args = ["install", pkg]
	puts "installing #{pkg}..."

	begin
	  Gem::GemRunner.new.run args
	rescue Gem::SystemExitException => e
	  exit e.exit_code
	end

when :list
	list = []
	dirs = Gem.all_load_paths.grep("msgpack-idl")
	dirs.each {|dir|
		path = File.join(dir, "msgpack/idl/lang")
		if File.directory?(path)
			list.concat Dir.entries(path)
		end
	}

	puts "available language modules:"
	list.each {|lang|
		puts "  #{lang}"
	}

when :generate
	if ARGV.length == 0
		usage nil
	end
	unless conf[:lang]
		usage "-g option is required."
	end

	lang = conf[:lang]
	out = conf[:out] || "gen-#{lang}"
	files = ARGV

	require 'parslet'
	require 'msgpack/idl/version'
	require 'msgpack/idl/module'
	require 'msgpack/idl/error'
	require 'msgpack/idl/ast'
	require 'msgpack/idl/ir'
	require 'msgpack/idl/parser/rule'
	require 'msgpack/idl/parser/transform'
	require 'msgpack/idl/parser'
	require 'msgpack/idl/evaluator'
	require 'msgpack/idl/generator'

	begin
		require "msgpack/idl/lang/#{lang}"
		available = true
	rescue LoadError
		available = false
	end
	if !available || !MessagePack::IDL::Generator.available?(lang)
		puts "Language module #{lang.dump} is not available."
		puts "Try to install it as follows:"
		puts "  $ #{prog} --install #{lang}"
		exit 1
	end

	parser = MessagePack::IDL::Parser.new
	files.each {|path|
		if path == "-"
			text = STDIN.read
			parser.parse(text, '(stdin)', '.')
		else
			parser.parse_file(path)
		end
	}
	ast = parser.ast

	if conf[:show_ast]
		require 'pp'
		$stderr.puts "AST:"
		$stderr.puts ast.pretty_inspect
	end

	ev = MessagePack::IDL::Evaluator.new
	ev.evaluate(ast)
	ev.evaluate_inheritance
	ir = ev.evaluate_spec(lang)

	if conf[:show_ir]
		require 'pp'
		$stderr.puts "IR:"
		$stderr.puts ir.pretty_inspect
	end

	gen = MessagePack::IDL::Generator.new
	gen.generate(lang, ir, out)
end

