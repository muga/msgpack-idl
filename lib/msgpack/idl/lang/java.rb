#
# MessagePack IDL Generator for Java
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
module MessagePack
module IDL
module Lang

require 'fileutils'
require 'tenjin'

class JavaGenerator < GeneratorModule
	Generator.register('java', self)

	include Tenjin::ContextHelper

	def initialize(ir, outdir)
		@ir = ir
		@outdir = outdir
	end

	def generate!
		gen_init
		gen_messages
		gen_servers
		gen_clients
	end

	def gen_init
		@datadir = File.join(File.dirname(__FILE__), 'java')

		@dir = File.join(@outdir, @ir.namespace)

		if @ir.namespace.empty?
			@package = ""
		else
			@package = "package #{@ir.namespace.join('.')};"
		end

		@engine = Tenjin::Engine.new(:cache => false)
	end

	def gen_messages
		render = get_render('message.java')

		@ir.messages.each {|t|
			@message = t
			render_write(render, t.name)
		}
		@message = nil
	end

	def gen_servers
		render = get_render('server.java')

		@ir.services.each {|s|
			@service = s
			s.versions.each {|v|
				@version = v.version
				@functions = v.functions
				@name = "#{s.name}_#{v.version}"
				render_write(render, 'server', @name)
			}
		}
		@service = nil
		@version = nil
		@functions = nil
		@name = nil
	end

	def gen_clients
		render = get_render('client.java')

		@ir.services.each {|s|
			@service = s
			s.versions.each {|v|
				@version = v.version
				@functions = v.functions
				@name = "#{s.name}_#{v.version}"
				render_write(render, 'client', @name)
			}
		}
		@service = nil
		@version = nil
		@functions = nil
		@name = nil
	end

	def get_render(*fnames)
		path = File.join(@datadir, *fnames)
		@engine.get_template(path)
	end

	def render_write(render, *fnames)
		code = render.render(self)
		path = File.join(@dir, *fnames)
		FileUtils.mkdir_p(File.dirname(path))
		path << '.java'
		File.open(path, "w") {|f|
			f.write(code)
		}
	end

	PRIMITIVE_TYPEMAP = {
		'void'   => 'void',
		'byte'   => 'byte',
		'short'  => 'short',
		'int'    => 'int',
		'long'   => 'long',
		'ubyte'  => 'short',
		'ushort' => 'int',
		'uint'   => 'long',
		'ulong'  => 'BigInteger',
		'float'  => 'float',
		'double' => 'double',
		'bool'   => 'boolean',
		'raw'    => 'ByteBuffer',
		'string' => 'String',
		'list'   => 'ArrayList',
		'map'    => 'HashMap',
	}

	def format_type(t)
		name = PRIMITIVE_TYPEMAP[t.name] || t.name
		if t.is_a?(IR::ParameterizedType)
			name + '<' +
				t.type_params.map {|tp| format_type(tp) }.join(', ') +
			'>'
		else
			name
		end
	end
end


end
end
end
