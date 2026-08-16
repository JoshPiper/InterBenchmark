--- Number and text formatting helpers.

return {
	groupName = "Internet's Benchmark Suite: Formatting",

	cases = {
		{
			name = "Title strips the whole extension",
			func = function()
				expect(INTERNET_BENCHMARK.Formatting.Title("modulo.lua")).to.equal("Modulo")
			end
		},

		{
			name = "Title cases every word",
			func = function()
				expect(INTERNET_BENCHMARK.Formatting.Title("local_vs_global")).to.equal("Local Vs Global")
			end
		},

		{
			name = "Title handles an underscored name with an extension at once",
			func = function()
				expect(INTERNET_BENCHMARK.Formatting.Title("for_loops.lua")).to.equal("For Loops")
			end
		},

		{
			name = "Prefix selects micro for sub-millisecond values",
			func = function()
				expect(INTERNET_BENCHMARK.Formatting:Prefix(0.0005)).to.equal(-6)
			end
		},

		{
			name = "Prefix selects milli for sub-second values",
			func = function()
				expect(INTERNET_BENCHMARK.Formatting:Prefix(0.5)).to.equal(-3)
			end
		},

		{
			name = "Prefix selects the empty prefix for values already in range",
			func = function()
				expect(INTERNET_BENCHMARK.Formatting:Prefix(1.5)).to.equal(0)
			end
		},

		{
			name = "Prefix has no answer for zero",
			func = function()
				expect(INTERNET_BENCHMARK.Formatting:Prefix(0)).to.beNil()
			end
		},

		{
			name = "AutoNumber formats a micro-scale value",
			func = function()
				expect(INTERNET_BENCHMARK.Formatting:AutoNumber(0.0005, nil, 2)).to.equal("500.00µ")
			end
		},

		{
			name = "AutoNumber formats a milli-scale value",
			func = function()
				expect(INTERNET_BENCHMARK.Formatting:AutoNumber(0.5, nil, 2)).to.equal("500.00m")
			end
		},

		{
			name = "AutoNumber formats an unscaled value",
			func = function()
				expect(INTERNET_BENCHMARK.Formatting:AutoNumber(1.5, nil, 3)).to.equal("1.500")
			end
		},

		{
			name = "AutoNumber keeps the sign of a negative value",
			func = function()
				expect(INTERNET_BENCHMARK.Formatting:AutoNumber(-0.0005, nil, 2)).to.equal("-500.00µ")
			end
		},

		{
			name = "AutoNumber formats a nano-scale value",
			func = function()
				expect(INTERNET_BENCHMARK.Formatting:AutoNumber(3.2e-9, nil, 2)).to.equal("3.20n")
			end
		},

		{
			name = "AutoNumber formats zero without crashing",
			func = function()
				expect(INTERNET_BENCHMARK.Formatting:AutoNumber(0, nil, 2)).to.equal("0.00")
			end
		},

		{
			name = "Number formats raw when given no prefix",
			func = function()
				expect(INTERNET_BENCHMARK.Formatting:Number(1234, nil)).to.equal("1234")
			end
		},

		{
			name = "Number formats against an explicit prefix",
			func = function()
				expect(INTERNET_BENCHMARK.Formatting:Number(0.001, -3)).to.equal("1m")
			end
		},

		{
			name = "ModalPrefix picks the majority prefix across a set of numbers",
			func = function()
				expect(INTERNET_BENCHMARK.Formatting:ModalPrefix({0.0005, 0.0007, 0.5})).to.equal(-6)
			end
		},

		{
			name = "ModalPrefix has no answer for an empty set",
			func = function()
				expect(INTERNET_BENCHMARK.Formatting:ModalPrefix({})).to.beNil()
			end
		},

		{
			name = "AutoNumbers scales an outlier to the modal prefix of its column",
			func = function()
				local formatted = INTERNET_BENCHMARK.Formatting:AutoNumbers(0.5, {0.0005, 0.0007, 0.0009}, 2)
				expect(formatted).to.equal("500000.00µ")
			end
		},

		{
			name = "EscapeHTML escapes angle brackets and ampersands",
			func = function()
				local escaped = INTERNET_BENCHMARK.Formatting.EscapeHTML("if a < b and c > d then return a & b end")
				expect(escaped).to.equal("if a &lt; b and c &gt; d then return a &amp; b end")
			end
		}
	}
}
