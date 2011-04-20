#{format_package}

import org.msgpack.MessageTypeException;
import org.msgpack.MessagePackable;

public enum #{@name} implements MessagePackable {
	<?rb @fields.each {|f| ?>
	#{f.name}(#{f.id}),
	<?rb } ?>
	;

	public static #{@name} enumOf(int id) {
		switch(id) {
		<?rb @fields.each {|f| ?>
		case #{f.id}:
			return #{f.name};
		<?rb } ?>
		default:
			throw new MessageTypeException();
		}
	}

	public void messagePack(Packer pk) throws IOException {
		pk.packInt(this.id);
	}

	private int id;

	public int id() {
		return this.id;
	}

	private #{@name}(int id) {
		this.id = id;
	}
}

