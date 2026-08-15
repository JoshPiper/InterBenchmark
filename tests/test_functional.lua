return function(t)
	local fn = INTERNET_BENCHMARK.Functional

	-- Captures a call's arguments as (count, ...), using select("#", ...)
	-- rather than # so that nils in the middle of the list are not lost.
	local function capture(...)
		return select("#", ...), ...
	end

	-- partial: stored arguments prepend correctly, call arguments append after them.

	do
		local p = fn.partial(capture, "a", "b")
		local n, a, b, c = p("c")
		t:eq(n, 3, "partial reports every stored and call argument")
		t:eq(a, "a", "partial keeps the first stored argument in place")
		t:eq(b, "b", "partial keeps the second stored argument in place")
		t:eq(c, "c", "partial appends the call argument after the stored ones")
	end

	do
		local p = fn.partial(capture, "x")
		local n1, a1, b1 = p("y")
		local n2, a2, b2 = p("y")
		t:eq(n1, n2, "calling the same partial twice with the same input reports the same count")
		t:eq(a1, a2, "calling the same partial twice with the same input returns the same first value")
		t:eq(b1, b2, "calling the same partial twice with the same input returns the same second value")
	end

	do
		local p = fn.partial(capture)
		local n3 = p("a", "b", "c")
		t:eq(n3, 3, "a longer call reports every one of its own arguments")

		local n1, a1, b1 = p("z")
		t:eq(n1, 1, "a shorter call after a longer one does not leak the previous call's extra arguments")
		t:eq(a1, "z", "a shorter call after a longer one still receives its own argument")
		t:eq(b1, nil, "a shorter call after a longer one does not see the previous call's second argument")
	end

	do
		local p = fn.partial(capture)
		local n = p()
		t:eq(n, 0, "zero stored arguments and zero call arguments report zero arguments")
	end

	do
		local p = fn.partial(capture, "a")
		local n = p(nil, nil)
		t:eq(n, 3, "nil call arguments are counted via select, not truncated by #")
	end

	-- flip: the first two arguments swap; trailing arguments keep their order.

	do
		local flipped = fn.flip(capture)
		local n, a, b, c, d = flipped(1, 2, 3, 4)
		t:eq(n, 4, "flip preserves the total argument count")
		t:eq(a, 2, "flip moves the second argument into first position")
		t:eq(b, 1, "flip moves the first argument into second position")
		t:eq(c, 3, "flip leaves trailing arguments in their original order (1)")
		t:eq(d, 4, "flip leaves trailing arguments in their original order (2)")
	end

	-- reverse: empty, single and n-argument cases, plus nil handling.

	-- The empty case does not fit the general pattern: reverse_h's `v`
	-- parameter has nothing bound to it when there are no varargs at all, so
	-- it defaults to nil like any unfilled parameter - and that nil is still
	-- returned. The result is one value (nil), not zero values.
	do
		local n = select("#", fn.reverse())
		t:eq(n, 1, "reverse of no arguments returns a single nil, not zero values")
	end

	do
		local n, a = capture(fn.reverse("only"))
		t:eq(n, 1, "reverse of a single argument returns exactly one value")
		t:eq(a, "only", "reverse leaves a single argument unchanged")
	end

	do
		local n, a, b, c = capture(fn.reverse(1, 2, 3))
		t:eq(n, 3, "reverse of three arguments returns exactly three values")
		t:eq(a, 3, "reverse moves the last argument to the front")
		t:eq(b, 2, "reverse leaves a middle argument in the middle")
		t:eq(c, 1, "reverse moves the first argument to the back")
	end

	do
		local n, a, b, c = capture(fn.reverse(1, nil, 3))
		t:eq(n, 3, "reverse preserves the argument count across a nil in the middle")
		t:eq(a, 3, "reverse moves the last argument to the front despite a nil elsewhere")
		t:eq(b, nil, "reverse keeps the nil argument in its reversed position")
		t:eq(c, 1, "reverse moves the first argument to the back despite a nil elsewhere")
	end

	-- compose: right-to-left ordering, the zero- and one-function edge cases, and multi-return passing.

	do
		local order = {}
		local function f(x) table.insert(order, "f"); return x + 1 end
		local function g(x) table.insert(order, "g"); return x * 2 end

		local composed = fn.compose(f, g)
		t:eq(composed(3), 7, "compose(f, g)(x) computes f(g(x))")
		t:eq(order[1], "g", "compose applies the rightmost function first")
		t:eq(order[2], "f", "compose applies the leftmost function last")
	end

	do
		local identity = fn.compose()
		local n, a, b = capture(identity(1, 2))
		t:eq(n, 2, "compose with zero functions returns an identity that preserves argument count")
		t:eq(a, 1, "compose with zero functions passes its input through unchanged (1)")
		t:eq(b, 2, "compose with zero functions passes its input through unchanged (2)")
	end

	do
		local function onlyFn(x) return x + 1 end
		t:eq(fn.compose(onlyFn), onlyFn, "compose of a single function returns that function as-is")
	end

	do
		local function pair(x) return x, x * 10 end
		local function sum(a, b) return a + b end
		local composed = fn.compose(sum, pair)
		t:eq(composed(3), 33, "compose passes every return value from one stage into the next")
	end
end
