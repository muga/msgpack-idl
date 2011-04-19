#{format_package}

import java.util.List;
import java.util.Map;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.io.IOException;
import org.msgpack.MessageTypeException;
import org.msgpack.MessagePackObject;

public class #{@name} implements MessagePackable, MessageUnpackable, MessageConvertable {
	<?rb @message.new_fields.each {|f| ?>
	private #{format_type(f.type)} #{f.name};
	<?rb } ?>

	public #{@name}() {
		super();
		<?rb @message.new_fields.each {|f| ?>
			#{format_initial_value("this.#{f.name}", f)}
		<?rb } ?>
	}

	<?rb @message.new_fields.each {|f| ?>
	public void set#{f.name.capitalize}(#{format_type(f.type)} value) {
		this.#{f.name} = v;
	}
	public #{format_type(f.type)} get#{f.name.capitalize}() {
		return this.#{f.name};
	}
	<?rb } ?>

	public void messagePack(Packer pk) throws IOException {
		pk.packArray(#{@message.max_id});
		<?rb 1.upto(@message.max_id) {|i| ?>
			<?rb if f = @message[i]; ?>
				pk.pack(this.#{f.name});
			<?rb else ?>
				pk.packNil();
			<?rb end ?>
		<?rb } ?>
	}

	public void messageUnpack(Unpacker pac) throws IOException, MessageTypeException {
		int len = pac.unpackArray();

		if(len < #{@message.max_required_id}) {
			throw new MessagePackObject("#{@message.name} requires at least #{@message.max_required_id} elements.");
		}

		<?rb 1.upto(@message.max_id) {|i| ?>
			<?rb f = @message[i] ?>
			<?rb if !f ?>
				<?rb if i > @message.max_required_id ?>
				if(len < #{i}) { return; }
				<?rb end ?>
				pac.unpackObject();
			<?rb elsif f.required? ?>
				<?rb if f.type.nullable_type? ?>
					if(!pac.tryUnpackNull()) {
						#{format_unpack("this.#{f.name}", "pac", f.type.real_type)}
					}
				<?rb else ?>
					if(!pac.tryUnpackNull()) {
						throw new MessageTypeException("#{@message.name}.#{f.name} is not nullable bug got nil");
					}
					#{format_unpack("this.#{f.name}", "pac", f.type.real_type)}
				<?rb end ?>
			<?rb elsif f.optional? ?>
				<?rb if i > @message.max_required_id ?>
				if(len < #{i}) { return; }
				<?rb end ?>
				if(!pac.tryUnpackNull()) {
					#{format_unpack("this.#{f.name}", "pac", f.type.real_type)}
				}
			<?rb end ?>
		<?rb } ?>

		for(int i=#{@message.max_id}; i < len; ++i) {
			pac.unpackObject();
		}
	}

	public void messageConvert(MessagePackObject obj) throws IOException, MessageTypeException {
		if(!obj.isArrayType()) {
			throw new MessageTypeException("target is not array");
		}
		MessagePackObject[] arr = obj.asArray();
		int len = arr.length;

		if(len < #{@message.max_required_id}) {
			throw new MessageTypeException("#{@message.name} requires at least #{@message.max_required_id} elements.");
		}

		MessagePackObject obj;

		<?rb 1.upto(@message.max_id) {|i| ?>
			<?rb f = @message[i] ?>
			<?rb if !f ?>
			<?rb elsif f.required? ?>
				obj = arr[i];
				<?rb if f.type.nullable_type? ?>
					if(!obj.isNil()) {
						#{format_convert("this.#{f.name}", "obj", f.type.real_type)}
					}
				<?rb else ?>
					if(!obj.isNil()) {
						throw new MessageTypeException("#{@message.name}.#{f.name} is not nullable bug got nil");
					}
					#{format_convert("this.#{f.name}", "obj", f.type.real_type)}
				<?rb end ?>
			<?rb elsif f.optional? ?>
				<?rb if i > @message.max_required_id ?>
				if(len < #{i}) { return; }
				<?rb end ?>
				obj = arr[i];
				if(!obj.isNil()) {
					#{format_convert("this.#{f.name}", "obj", f.type.real_type)}
				}
			<?rb end ?>
		<?rb } ?>
	}
}

