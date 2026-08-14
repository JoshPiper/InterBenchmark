-- Rendering functions only exist clientside.
TRIAL
	:Name("surface.SetDrawColor")
	:Description(
		"Every practical way to call surface.SetDrawColor with a given colour: raw numeric components (direct or through locals), a fresh "
		.. "Color() object (whole - via its single-argument overload - unpacked, or read component-by-component), and the same again for a "
		.. "Color() built once and reused, each with and without an explicit alpha."
	)
	:Order(101)
	:Tag("default")
	:If(CLIENT)
