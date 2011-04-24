class #{@name}
<?rb if @super_class ?>
		extends #{@super_class}
<?rb end ?>
		implements MessagePackable, MessageUnpackable, MessageConvertable {

	<?rb @message.new_fields.each {|f| ?>
	protected #{format_type(f.type)} #{f.name};
	<?rb } ?>

	public #{@name}() {
	<?rb if @super_class ?>
		super();
	<?rb end ?>
	<?rb @message.new_fields.each {|f| ?>
		#{format_initial_value("this.#{f.name}", f)}
	<?rb } ?>
	}

	<?rb fields = @message.all_fields ?>
	<?rb unless fields.empty? ?>
	public #{@name}(#{ fields.map {|f| format_type(f.type)+" "+f.name }.join(', ') }) {
		<?rb fields.each {|f| ?>
		this.#{f.name} = #{f.name};
		<?rb } ?>
	}
	<?rb end ?>

	<?rb if @message.max_id != @message.max_required_id && @message.max_required_id > 0 ?>
		<?rb fields = @message.all_fields[0, @message.max_required_id] ?>
		public #{@name}(#{ fields.map {|f| format_type(f.type)+" "+f.name }.join(', ') }) {
			<?rb fields.each {|f| ?>
				this.#{f.name} = #{f.name};
			<?rb } ?>
			<?rb @message.all_fields[@message.max_required_id..-1].each {|f| ?>
				#{format_initial_value("this.#{f.name}", f)}
			<?rb } ?>
		}
	<?rb end ?>

	<?rb @message.new_fields.each {|f| ?>
	public void set#{f.name.capitalize}(#{format_type(f.type)} #{f.name}) {
		this.#{f.name} = #{f.name};
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
			throw new MessageTypeException("#{@message.name} requires at least #{@message.max_required_id} elements.");
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

	public void messageConvert(MessagePackObject obj) throws MessageTypeException {
		if(!obj.isArrayType()) {
			throw new MessageTypeException("target is not array");
		}
		MessagePackObject[] arr = obj.asArray();
		int len = arr.length;

		if(len < #{@message.max_required_id}) {
			throw new MessageTypeException("#{@message.name} requires at least #{@message.max_required_id} elements.");
		}

		<?rb 1.upto(@message.max_id) {|i| ?>
			<?rb f = @message[i] ?>
			<?rb if !f ?>
			<?rb elsif f.required? ?>
				obj = arr[#{i-1}];
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
				obj = arr[#{i-1}];
				if(!obj.isNil()) {
					#{format_convert("this.#{f.name}", "obj", f.type.real_type)}
				}
			<?rb end ?>
		<?rb } ?>
	}
}
