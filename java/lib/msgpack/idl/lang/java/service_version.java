#{format_package}

import java.util.List;
import java.util.Map;
import java.util.ArrayList;
import java.util.HashMap;
import java.io.IOException;
import org.msgpack.Packer;
import org.msgpack.Unpacker;
import org.msgpack.MessageTypeException;
import org.msgpack.MessagePackObject;
import org.msgpack.MessagePackable;
import org.msgpack.MessageUnpackable;
import org.msgpack.MessageConvertable;

public abstract class #{@name} {
	<?rb @functions.each {|f| ?>
	public static #{format_message(f, "A#{f.name}")}
	<?rb } ?>
}

