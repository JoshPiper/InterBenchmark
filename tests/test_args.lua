return function(t)
	local BENCH = INTERNET_BENCHMARK

	-- ParseArgs: flags.

	do
		local flags, positional = BENCH:ParseArgs({"--dynamic"})
		t:eq(flags.dynamic, true, "bare flag parses to true")
		t:eq(#positional, 0, "bare flag leaves no positionals")
	end

	do
		local flags = BENCH:ParseArgs({"--tags=table,rendering"})
		t:eq(flags.tags, "table,rendering", "flag=value parses to the raw string")
	end

	do
		local flags = BENCH:ParseArgs({"--tags="})
		t:eq(flags.tags, "", "flag= with no value parses to an empty string")
	end

	do
		local flags = BENCH:ParseArgs({"--DYNAMIC"})
		t:eq(flags.dynamic, true, "flag names are lowercased")
	end

	do
		local flags = BENCH:ParseArgs({"--tags=Table,Rendering"})
		t:eq(flags.tags, "Table,Rendering", "flag values keep their case")
	end

	-- ParseArgs: positionals, and the ordering ambiguity this issue fixes.

	do
		local flags, positional = BENCH:ParseArgs({"dynamic"})
		t:eq(flags.dynamic, nil, "a bare word is never treated as a flag")
		t:eq(positional[1], "dynamic", "a bare word is a positional")
	end

	do
		local flags, positional = BENCH:ParseArgs({"--dynamic", "array_insertion", "for_loops"})
		t:eq(flags.dynamic, true, "flags before positionals still parse")
		t:eq(positional[1], "array_insertion", "positional order is preserved (1)")
		t:eq(positional[2], "for_loops", "positional order is preserved (2)")
	end

	do
		local flags, positional = BENCH:ParseArgs({"array_insertion", "--dynamic", "for_loops"})
		t:eq(flags.dynamic, true, "an interleaved flag still parses")
		t:eq(positional[1], "array_insertion", "interleaved positional order is preserved (1)")
		t:eq(positional[2], "for_loops", "interleaved positional order is preserved (2)")
	end

	do
		local _, positional = BENCH:ParseArgs({"--", "-x"})
		t:eq(positional[1], "--", "a bare -- is positional")
		t:eq(positional[2], "-x", "a single-dash token is positional")
	end

	-- ParseArgs: repeated flags collapse to a sequential table.

	do
		local flags = BENCH:ParseArgs({"--tags=a", "--tags=b", "--tags=c"})
		t:eq(type(flags.tags), "table", "a repeated flag collapses to a table")
		t:eq(flags.tags[1], "a", "repeated flag values keep their order (1)")
		t:eq(flags.tags[2], "b", "repeated flag values keep their order (2)")
		t:eq(flags.tags[3], "c", "repeated flag values keep their order (3)")
	end

	do
		local flags = BENCH:ParseArgs({"--x", "--x=v"})
		t:eq(type(flags.x), "table", "mixing bare and valued repeats still collapses to a table")
		t:eq(flags.x[1], true, "mixed repeat keeps the bare value")
		t:eq(flags.x[2], "v", "mixed repeat keeps the valued value")
	end

	-- ParseArgs: empty input.

	do
		local flags, positional = BENCH:ParseArgs(nil)
		t:eq(next(flags), nil, "nil args produces an empty flag table")
		t:eq(#positional, 0, "nil args produces an empty positional table")
	end

	do
		local flags, positional = BENCH:ParseArgs({})
		t:eq(next(flags), nil, "empty args produces an empty flag table")
		t:eq(#positional, 0, "empty args produces an empty positional table")
	end

	-- ArgCompleter.

	local trialSchema = {
		flags = {"dynamic"},
		positionals = {function() return {"array_insertion", "for_loops", "local_vs_global"} end},
	}

	do
		local complete = BENCH:ArgCompleter(trialSchema)
		local suggestions = complete("internet_benchmark_trial", "")
		t:eq(#suggestions, 3, "empty input suggests every trial name")
		t:eq(suggestions[1], "internet_benchmark_trial array_insertion", "empty input suggests the full command line (1)")
	end

	do
		local complete = BENCH:ArgCompleter(trialSchema)
		local suggestions = complete("internet_benchmark_trial", "for")
		t:eq(#suggestions, 1, "a partial name matches only that trial")
		t:eq(suggestions[1], "internet_benchmark_trial for_loops", "a partial name completes to the full name")
	end

	do
		local complete = BENCH:ArgCompleter(trialSchema)
		local suggestions = complete("internet_benchmark_trial", "--dynamic loc")
		t:eq(#suggestions, 1, "a leading flag is preserved while completing the name")
		t:eq(suggestions[1], "internet_benchmark_trial --dynamic local_vs_global", "the preserved flag stays ahead of the completed name")
	end

	do
		local complete = BENCH:ArgCompleter(trialSchema)
		local suggestions = complete("internet_benchmark_trial", "local_vs_global --d")
		t:eq(#suggestions, 1, "the flag can be completed once the name is already typed")
		t:eq(suggestions[1], "internet_benchmark_trial local_vs_global --dynamic", "a trailing flag completes with the name preserved")
	end

	do
		local complete = BENCH:ArgCompleter(trialSchema)
		local suggestions = complete("internet_benchmark_trial", "local_vs_global --dynamic --d")
		t:eq(#suggestions, 0, "an already-typed flag is not suggested again")
	end

	do
		local twoSlotSchema = {
			positionals = {
				function() return {"alpha"} end,
				function() return {"beta"} end,
			},
		}
		local complete = BENCH:ArgCompleter(twoSlotSchema)
		local suggestions = complete("cmd", "alpha ")
		t:eq(#suggestions, 1, "the second positional slot uses its own provider")
		t:eq(suggestions[1], "cmd alpha beta", "the second slot completes after the first is filled")
	end

	-- ParseTagList.

	do
		local tags = BENCH:ParseTagList(nil)
		t:eq(#tags, 0, "nil produces an empty list")
	end

	do
		local tags = BENCH:ParseTagList(true)
		t:eq(#tags, 0, "a bare flag (true) produces an empty list")
	end

	do
		local tags = BENCH:ParseTagList("default")
		t:eq(#tags, 1, "a single value produces a single-entry list")
		t:eq(tags[1], "default", "the value is kept")
	end

	do
		local tags = BENCH:ParseTagList("Default,Rendering")
		t:eq(#tags, 2, "a comma-separated value splits into multiple tags")
		t:eq(tags[1], "default", "tags are lower-cased (1)")
		t:eq(tags[2], "rendering", "tags are lower-cased (2)")
	end

	do
		local tags = BENCH:ParseTagList({"default", "rendering,slow"})
		t:eq(#tags, 3, "a repeated-flag table flattens, splitting each entry on commas")
		t:eq(tags[1], "default", "flattened tags keep their order (1)")
		t:eq(tags[2], "rendering", "flattened tags keep their order (2)")
		t:eq(tags[3], "slow", "flattened tags keep their order (3)")
	end

	do
		local tags = BENCH:ParseTagList({"default", true})
		t:eq(#tags, 1, "a non-string entry within a repeated flag is skipped")
		t:eq(tags[1], "default", "the string entry is still kept")
	end

	-- TagsMatch.

	do
		local matches = BENCH:TagsMatch({}, {}, {})
		t:eq(matches, true, "no filters at all matches an untagged item")
	end

	do
		local matches = BENCH:TagsMatch({"default"}, {}, {})
		t:eq(matches, true, "no filters at all matches a tagged item")
	end

	do
		local matches = BENCH:TagsMatch({"default"}, {"default"}, {})
		t:eq(matches, true, "an include filter matches an item with that tag")
	end

	do
		local matches = BENCH:TagsMatch({"slow"}, {"default"}, {})
		t:eq(matches, false, "an include filter excludes an item without a matching tag")
	end

	do
		local matches = BENCH:TagsMatch({}, {"default"}, {})
		t:eq(matches, false, "an include filter excludes an untagged item")
	end

	do
		local matches = BENCH:TagsMatch({"default", "slow"}, {"slow"}, {})
		t:eq(matches, true, "an include filter matches on any one of an item's several tags")
	end

	do
		local matches = BENCH:TagsMatch({"default"}, {}, {"default"})
		t:eq(matches, false, "a skip filter excludes a matching item even with no include filter")
	end

	do
		local matches = BENCH:TagsMatch({"other"}, {}, {"default"})
		t:eq(matches, true, "a skip filter leaves a non-matching item untouched")
	end

	do
		local matches = BENCH:TagsMatch({"default"}, {"default"}, {"default"})
		t:eq(matches, false, "a skip filter takes precedence over a matching include filter")
	end
end
