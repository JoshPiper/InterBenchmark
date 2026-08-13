return function(t)
	local f = INTERNET_BENCHMARK.Formatting

	-- Title casing.
	t:eq(f.Title("modulo.lua"), "Modulo", "Title strips the whole extension")
	t:eq(f.Title("local_vs_global"), "Local Vs Global", "Title cases every word")
	t:eq(f.Title("for_loops.lua"), "For Loops", "Title handles both at once")

	-- Prefix selection.
	t:eq(f:Prefix(0.0005), -6, "0.5ms selects micro")
	t:eq(f:Prefix(0.5), -3, "0.5s selects milli")
	t:eq(f:Prefix(1.5), 0, "1.5s selects the empty prefix")
	t:eq(f:Prefix(0), nil, "zero has no prefix")

	-- Number formatting.
	t:eq(f:AutoNumber(0.0005, nil, 2), "500.00µ", "micro formatting")
	t:eq(f:AutoNumber(0.5, nil, 2), "500.00m", "milli formatting")
	t:eq(f:AutoNumber(1.5, nil, 3), "1.500", "unit formatting")
	t:eq(f:AutoNumber(-0.0005, nil, 2), "-500.00µ", "negative numbers keep their sign")
	t:eq(f:AutoNumber(3.2e-9, nil, 2), "3.20n", "nano formatting")
	t:eq(f:AutoNumber(0, nil, 2), "0.00", "zero formats without crashing")
	t:eq(f:Number(1234, nil), "1234", "nil prefix formats raw")
	t:eq(f:Number(0.001, -3), "1m", "explicit prefix")

	-- Modal prefixes keep a column in one unit.
	t:eq(f:ModalPrefix({0.0005, 0.0007, 0.5}), -6, "modal prefix picks the majority")
	t:eq(f:ModalPrefix({}), nil, "empty sets have no modal prefix")
	t:eq(f:AutoNumbers(0.5, {0.0005, 0.0007, 0.0009}, 2), "500000.00µ", "outliers scale to the modal prefix")

	-- HTML escaping.
	t:eq(
		f.EscapeHTML("if a < b and c > d then return a & b end"),
		"if a &lt; b and c &gt; d then return a &amp; b end",
		"EscapeHTML handles angle brackets and ampersands"
	)
end
