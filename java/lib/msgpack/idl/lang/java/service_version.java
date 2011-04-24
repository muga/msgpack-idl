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
		<?rb if f.inherited? ?>
			public static class A#{f.name} extends #{@service.name}_#{f.inherit_version}.A#{f.name} {
			}
		<?rb else ?>
			public static #{format_message(f, "A#{f.name}")}
		<?rb end ?>
	<?rb } ?>
}

