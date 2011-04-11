#{@package}

import java.util.List;
import java.util.Set;
import java.util.Map;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.HashMap;
import java.io.IOException;
import org.msgpack.MessageTypeException;

public class #{@message.name} implements MessagePackable, MessageUnpackable, MessageConvertable {
	<?rb @message.new_fields.each {|field| ?>
	private #{format_type(field.type)} #{field.name};
	<?rb } ?>

	public void messagePack(Packer _Pk) throws IOException {
		pk.packArray(#{@message.max_id});
		<?rb 1.upto(@message.max_id) {|i| ?>
		<?rb if f = @message[i]; ?>
		_Pk.pack(this.#{f.name});
		<?rb else ?>
		_Pk.packNil();
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
		pac.unpackObject();
		<?rb elsif f.required? ?>
		this.#{f.name} = pac.#{format_unpack(f.type)};
		<?rb elsif i <= @message.max_required_id ?>
		if(!pac.tryUnpackNull()) {
			this.#{f.name} = pac.#{format_unpack(f.type)};
		}
		<?rb else ?>
		if(len > #{i-1}) {
			this.#{f.name} = pac.#{format_unpack(f.type)};
		}
		<?rb end ?>
		<?rb } ?>
	}

	public void messageConvert(MessagePackObject obj) throws IOException, MessageTypeException {
		if(!obj.isArrayType()) {
			throw new MessageTypeException("target is not array");
		}
		MessagePackObject[] arr = obj.asArray();
		int len = arr.length;

		if(len < #{@message.max_required_id}) {
			throw new MessagePackObject("#{@message.name} requires at least #{@message.max_required_id} elements.");
		}

		<?rb 1.upto(@message.max_id) {|i| ?>
		<?rb if f = @message[i] ?>

		<?rb if f.required? ?>
		this.#{f.name} = arr[#{i}].#{format_convert(f.type)};  // TODO
		<?rb else ?>
		<?rb if i > @message.max_required_id  # optional ?>
		if(len < #{i-1}) { return; }
		<?rb end ?>
		if(!arr[#{i}].isNil()) {
			this.#{f.name} = arr[#{i}].#{format_convert(f.type)};
		}
		<?rb end ?>

		<?rb end ?>
		<?rb } ?>
	}
}

