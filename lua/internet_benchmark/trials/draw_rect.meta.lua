-- Rendering functions only exist clientside.
TRIAL
	:Name("DrawRect vs RoundedBox")
	:Description("draw.RoundedBox is a convenience wrapper that rebuilds a rounded-rectangle mesh every call, even at radius 0 - surface.DrawRect issues one raw rectangle draw call directly.")
	:Order(100)
	:Tag("default")
	:If(CLIENT)
