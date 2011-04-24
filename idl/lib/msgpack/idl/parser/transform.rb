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
module MessagePack
module IDL

if defined?(RUBY_VERSION) && RUBY_VERSION >= "1.9.0" && RUBY_VERSION < "1.9.2"
	class Parslet::Pattern::Context
		AST = MessagePack::IDL::AST
	end
end

class ParsletTransform < Parslet::Transform
	rule(:sequence_x => simple(:x)) {
		x
	}

	rule(:sequence_xs => simple(:xs)) {
		xs
	}

	rule(:sequence => simple(:x)) {
		x ? AST::Sequence.new([x]) : AST::Sequence.new
	}

	rule(:sequence => sequence(:x)) {
		AST::Sequence.new(x)
	}


	rule(:val_int => simple(:i)) {
		i.to_i
	}

	rule(:val_optional => simple(:x)) {
		AST::FIELD_OPTIONAL
	}

	rule(:val_required => simple(:x)) {
		AST::FIELD_REQUIRED
	}

	rule(:val_override => simple(:x)) {
		AST::FUNC_OVERRIDE
	}

	rule(:val_remove => simple(:x)) {
		AST::FUNC_REMOVE
	}

	rule(:val_add => simple(:x)) {
		AST::FUNC_ADD
	}


	rule(:name => simple(:n)) {
		n.to_s
	}


	rule(:field_id => simple(:i),
			 :field_modifier => simple(:m),
			 :field_type => simple(:t),
			 :field_name => simple(:n),
			 :field_value => simple(:v)) {
		m = m() ? m() : AST::FIELD_REQUIRED
		if v == nil
			AST::Field.new(i, t, m, n)
		else
			AST::ValueAssignedField.new(i, t, m, n, v)
		end
	}

	rule(:generic_type => simple(:n),
			 :type_params => simple(:tp)) {
		if tp
			AST::GenericType.new(n, tp)
		else
			AST::Type.new(n)
		end
	}

	rule(:field_type => simple(:t),
			 :field_type_maybe => simple(:n)) {
		nullable = !!n
		if t.is_a?(AST::GenericType)
			AST::GenericType.new(t.name, t.type_params, nullable)
		else
			AST::Type.new(t.name, nullable)
		end
	}


	rule(:message_name => simple(:n),
			 :message_body => sequence(:b),
			 :super_class => simple(:sc)) {
		AST::Message.new(n, sc, b)
	}

	rule(:exception_name => simple(:n),
			 :exception_body => sequence(:b),
			 :super_class => simple(:sc)) {
		AST::Exception.new(n, sc, b)
	}


	rule(:enum_field_id => simple(:i),
			 :enum_field_name => simple(:n)) {
		AST::EnumField.new(i, n)
	}

	rule(:enum_name => simple(:n),
			 :enum_body => sequence(:b)) {
		AST::Enum.new(n, b)
	}


	rule(:return_type => simple(:rt),
			 :func_name => simple(:n),
			 :func_args => simple(:a),
			 :func_throws => simple(:ex)) {
		AST::Func.new(n, rt, a, ex)
	}

	rule(:inherit_all => simple(:_)) {
		AST::InheritAll.new
	}

	rule(:inherit_name => simple(:n)) {
		AST::InheritName.new(n)
	}

	rule(:inherit_func => simple(:f)) {
		AST::InheritFunc.new(f.name, f.return_type, f.args, f.exceptions)
	}

	rule(:service_name => simple(:n),
			 :service_version => simple(:v),
			 :service_funcs => sequence(:fs)) {
		AST::Service.new(n, v, fs)
	}


	rule(:scope_service => simple(:s),
			 :scope_service_version => simple(:v),
			 :scope_name => simple(:n),
			 :scope_default => simple(:d)) {
		if d
			AST::Scope.new(s, v, n, true)
		else
			AST::Scope.new(s, v, n, false)
		end
	}

	rule(:application_name => simple(:n),
			 :application_body => sequence(:b)) {
		AST::Application.new(n, b)
	}


	rule(:namespace_name => simple(:n)) {
		AST::Namespace.new(n, nil)
	}

	rule(:namespace_name => simple(:n),
			 :namespace_lang => simple(:l)) {
		AST::Namespace.new(n, l)
	}


	rule(:path => simple(:n)) {
		n
	}

	rule(:include => simple(:n)) {
		AST::Include.new(n.to_s)
	}


	rule(:document => sequence(:es)) {
		AST::Document.new(es)
	}


	rule(:literal_const => simple(:n)) {
		AST::ConstLiteral.new(n)
	}

	rule(:literal_enum_name => simple(:n),
			 :literal_enum_field => simple(:f)) {
		AST::EnumLiteral.new(n, f)
	}

	rule(:literal_int => simple(:i)) {
		AST::IntLiteral.new(i.to_i)
	}

	rule(:literal_float => simple(:f)) {
		AST::FloatLiteral.new(f.to_f)
	}

	rule(:literal_str_dq => simple(:s)) {
		s.to_s.gsub(/\\(.)/) {|e|
			eval("\"\\#{$~[1]}\"")  # TODO escape
		}
	}

	rule(:literal_str_sq => simple(:s)) {
		s.to_s
	}

	rule(:literal_str_seq => sequence(:ss)) {
		AST::StringLiteral.new(ss.join)
	}

	rule(:literal_nil => simple(:_)) {
		AST::NilLiteral.new
	}

	rule(:literal_true => simple(:_)) {
		AST::TrueLiteral.new
	}

	rule(:literal_false => simple(:_)) {
		AST::FalseLiteral.new
	}

	#rule(:literal_list => simple(:a)) {
	#	AST::ListLiteral.new(Array.new(a))
	#}

	#rule(:literal_map => simple(:ps)) {
	#	AST::MapLiteral.new(Array.new(ps))
	#}

	#rule(:literal_map_key => simple(:k), :literal_map_value => simple(:v)) {
	#	AST::MapLiteralPair.new(k, v)
	#}
end


end
end
