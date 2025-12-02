extends Label

func msg(txt: String) -> void:
	self.text += txt + "\n"

	# If there are more than three lines of text, remove the oldest line
	if self.text.count("\n") > 3:
		var lines = self.text.split("\n")
		lines.remove_at(0)
		self.text = "\n".join(lines)

func clear_msgs() -> void:
	self.text = ""
