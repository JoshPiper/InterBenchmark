--- Console command argument parsing: flags, positionals, tags and completion.

return {
	groupName = "Internet's Benchmark Suite: Argument Parsing",

	cases = {
		{
			name = "ParseArgs: a bare flag parses to true and leaves no positionals",
			func = function()
				local flags, positional = INTERNET_BENCHMARK:ParseArgs({"--dynamic"})
				expect(flags.dynamic).to.beTrue()
				expect(#positional).to.equal(0)
			end
		},

		{
			name = "ParseArgs: flag=value parses to the raw string",
			func = function()
				local flags = INTERNET_BENCHMARK:ParseArgs({"--tags=table,rendering"})
				expect(flags.tags).to.equal("table,rendering")
			end
		},

		{
			name = "ParseArgs: flag= with no value parses to an empty string",
			func = function()
				local flags = INTERNET_BENCHMARK:ParseArgs({"--tags="})
				expect(flags.tags).to.equal("")
			end
		},

		{
			name = "ParseArgs: flag names are lowercased",
			func = function()
				local flags = INTERNET_BENCHMARK:ParseArgs({"--DYNAMIC"})
				expect(flags.dynamic).to.beTrue()
			end
		},

		{
			name = "ParseArgs: flag values keep their case",
			func = function()
				local flags = INTERNET_BENCHMARK:ParseArgs({"--tags=Table,Rendering"})
				expect(flags.tags).to.equal("Table,Rendering")
			end
		},

		{
			name = "ParseArgs: a bare word is never treated as a flag",
			func = function()
				local flags, positional = INTERNET_BENCHMARK:ParseArgs({"dynamic"})
				expect(flags.dynamic).to.beNil()
				expect(positional[1]).to.equal("dynamic")
			end
		},

		{
			name = "ParseArgs: flags before positionals still parse, order preserved",
			func = function()
				local flags, positional = INTERNET_BENCHMARK:ParseArgs({"--dynamic", "array_insertion", "for_loops"})
				expect(flags.dynamic).to.beTrue()
				expect(positional[1]).to.equal("array_insertion")
				expect(positional[2]).to.equal("for_loops")
			end
		},

		{
			name = "ParseArgs: an interleaved flag still parses, order preserved",
			func = function()
				local flags, positional = INTERNET_BENCHMARK:ParseArgs({"array_insertion", "--dynamic", "for_loops"})
				expect(flags.dynamic).to.beTrue()
				expect(positional[1]).to.equal("array_insertion")
				expect(positional[2]).to.equal("for_loops")
			end
		},

		{
			name = "ParseArgs: a bare -- and a single-dash token are both positional",
			func = function()
				local _, positional = INTERNET_BENCHMARK:ParseArgs({"--", "-x"})
				expect(positional[1]).to.equal("--")
				expect(positional[2]).to.equal("-x")
			end
		},

		{
			name = "ParseArgs: a repeated flag collapses into an ordered table",
			func = function()
				local flags = INTERNET_BENCHMARK:ParseArgs({"--tags=a", "--tags=b", "--tags=c"})
				expect(flags.tags).to.beA("table")
				expect(flags.tags[1]).to.equal("a")
				expect(flags.tags[2]).to.equal("b")
				expect(flags.tags[3]).to.equal("c")
			end
		},

		{
			name = "ParseArgs: mixing a bare and a valued repeat still collapses to a table",
			func = function()
				local flags = INTERNET_BENCHMARK:ParseArgs({"--x", "--x=v"})
				expect(flags.x).to.beA("table")
				expect(flags.x[1]).to.beTrue()
				expect(flags.x[2]).to.equal("v")
			end
		},

		{
			name = "ParseArgs: nil args produce empty flag and positional tables",
			func = function()
				local flags, positional = INTERNET_BENCHMARK:ParseArgs(nil)
				expect(next(flags)).to.beNil()
				expect(#positional).to.equal(0)
			end
		},

		{
			name = "ParseArgs: empty args produce empty flag and positional tables",
			func = function()
				local flags, positional = INTERNET_BENCHMARK:ParseArgs({})
				expect(next(flags)).to.beNil()
				expect(#positional).to.equal(0)
			end
		},

		{
			name = "ArgCompleter: empty input suggests every trial name",
			func = function()
				local trialSchema = {
					flags = {"dynamic"},
					positionals = {function() return {"array_insertion", "for_loops", "local_vs_global"} end}
				}

				local complete = INTERNET_BENCHMARK:ArgCompleter(trialSchema)
				local suggestions = complete("internet_benchmark_trial", "")

				expect(#suggestions).to.equal(3)
				expect(suggestions[1]).to.equal("internet_benchmark_trial array_insertion")
			end
		},

		{
			name = "ArgCompleter: a partial name completes to the full name",
			func = function()
				local trialSchema = {
					flags = {"dynamic"},
					positionals = {function() return {"array_insertion", "for_loops", "local_vs_global"} end}
				}

				local complete = INTERNET_BENCHMARK:ArgCompleter(trialSchema)
				local suggestions = complete("internet_benchmark_trial", "for")

				expect(#suggestions).to.equal(1)
				expect(suggestions[1]).to.equal("internet_benchmark_trial for_loops")
			end
		},

		{
			name = "ArgCompleter: a leading flag is preserved while completing the name",
			func = function()
				local trialSchema = {
					flags = {"dynamic"},
					positionals = {function() return {"array_insertion", "for_loops", "local_vs_global"} end}
				}

				local complete = INTERNET_BENCHMARK:ArgCompleter(trialSchema)
				local suggestions = complete("internet_benchmark_trial", "--dynamic loc")

				expect(#suggestions).to.equal(1)
				expect(suggestions[1]).to.equal("internet_benchmark_trial --dynamic local_vs_global")
			end
		},

		{
			name = "ArgCompleter: a trailing flag completes once the name is already typed",
			func = function()
				local trialSchema = {
					flags = {"dynamic"},
					positionals = {function() return {"array_insertion", "for_loops", "local_vs_global"} end}
				}

				local complete = INTERNET_BENCHMARK:ArgCompleter(trialSchema)
				local suggestions = complete("internet_benchmark_trial", "local_vs_global --d")

				expect(#suggestions).to.equal(1)
				expect(suggestions[1]).to.equal("internet_benchmark_trial local_vs_global --dynamic")
			end
		},

		{
			name = "ArgCompleter: an already-typed flag is not suggested again",
			func = function()
				local trialSchema = {
					flags = {"dynamic"},
					positionals = {function() return {"array_insertion", "for_loops", "local_vs_global"} end}
				}

				local complete = INTERNET_BENCHMARK:ArgCompleter(trialSchema)
				local suggestions = complete("internet_benchmark_trial", "local_vs_global --dynamic --d")

				expect(#suggestions).to.equal(0)
			end
		},

		{
			name = "ArgCompleter: the second positional slot uses its own provider",
			func = function()
				local twoSlotSchema = {
					positionals = {
						function() return {"alpha"} end,
						function() return {"beta"} end
					}
				}

				local complete = INTERNET_BENCHMARK:ArgCompleter(twoSlotSchema)
				local suggestions = complete("cmd", "alpha ")

				expect(#suggestions).to.equal(1)
				expect(suggestions[1]).to.equal("cmd alpha beta")
			end
		},

		{
			name = "ParseTagList: nil produces an empty list",
			func = function()
				local tags = INTERNET_BENCHMARK:ParseTagList(nil)
				expect(#tags).to.equal(0)
			end
		},

		{
			name = "ParseTagList: a bare flag (true) produces an empty list",
			func = function()
				local tags = INTERNET_BENCHMARK:ParseTagList(true)
				expect(#tags).to.equal(0)
			end
		},

		{
			name = "ParseTagList: a single value produces a single-entry list",
			func = function()
				local tags = INTERNET_BENCHMARK:ParseTagList("default")
				expect(#tags).to.equal(1)
				expect(tags[1]).to.equal("default")
			end
		},

		{
			name = "ParseTagList: a comma-separated value splits and lower-cases",
			func = function()
				local tags = INTERNET_BENCHMARK:ParseTagList("Default,Rendering")
				expect(#tags).to.equal(2)
				expect(tags[1]).to.equal("default")
				expect(tags[2]).to.equal("rendering")
			end
		},

		{
			name = "ParseTagList: a repeated-flag table flattens, splitting each entry on commas",
			func = function()
				local tags = INTERNET_BENCHMARK:ParseTagList({"default", "rendering,slow"})
				expect(#tags).to.equal(3)
				expect(tags[1]).to.equal("default")
				expect(tags[2]).to.equal("rendering")
				expect(tags[3]).to.equal("slow")
			end
		},

		{
			name = "ParseTagList: a non-string entry within a repeated flag is skipped",
			func = function()
				local tags = INTERNET_BENCHMARK:ParseTagList({"default", true})
				expect(#tags).to.equal(1)
				expect(tags[1]).to.equal("default")
			end
		},

		{
			name = "TagsMatch: no filters at all matches an untagged item",
			func = function()
				expect(INTERNET_BENCHMARK:TagsMatch({}, {}, {})).to.beTrue()
			end
		},

		{
			name = "TagsMatch: no filters at all matches a tagged item",
			func = function()
				expect(INTERNET_BENCHMARK:TagsMatch({"default"}, {}, {})).to.beTrue()
			end
		},

		{
			name = "TagsMatch: an include filter matches an item with that tag",
			func = function()
				expect(INTERNET_BENCHMARK:TagsMatch({"default"}, {"default"}, {})).to.beTrue()
			end
		},

		{
			name = "TagsMatch: an include filter excludes an item without a matching tag",
			func = function()
				expect(INTERNET_BENCHMARK:TagsMatch({"slow"}, {"default"}, {})).to.beFalse()
			end
		},

		{
			name = "TagsMatch: an include filter excludes an untagged item",
			func = function()
				expect(INTERNET_BENCHMARK:TagsMatch({}, {"default"}, {})).to.beFalse()
			end
		},

		{
			name = "TagsMatch: an include filter matches on any one of an item's several tags",
			func = function()
				expect(INTERNET_BENCHMARK:TagsMatch({"default", "slow"}, {"slow"}, {})).to.beTrue()
			end
		},

		{
			name = "TagsMatch: a skip filter excludes a matching item even with no include filter",
			func = function()
				expect(INTERNET_BENCHMARK:TagsMatch({"default"}, {}, {"default"})).to.beFalse()
			end
		},

		{
			name = "TagsMatch: a skip filter leaves a non-matching item untouched",
			func = function()
				expect(INTERNET_BENCHMARK:TagsMatch({"other"}, {}, {"default"})).to.beTrue()
			end
		},

		{
			name = "TagsMatch: a skip filter takes precedence over a matching include filter",
			func = function()
				expect(INTERNET_BENCHMARK:TagsMatch({"default"}, {"default"}, {"default"})).to.beFalse()
			end
		},

		{
			name = "TagsMatch: a non-list filter is treated as no filter at all",
			func = function()
				expect(INTERNET_BENCHMARK:TagsMatch({"default"}, "default", "default")).to.beTrue()
				expect(INTERNET_BENCHMARK:TagsMatch({"default"}, true, 7)).to.beTrue()
				expect(INTERNET_BENCHMARK:TagsMatch("default", {}, {})).to.beTrue()
			end
		}
	}
}
