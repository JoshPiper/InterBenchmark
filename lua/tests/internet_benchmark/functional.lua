--- Pure-function helpers: partial application, flipping, reversal and composition.

--- Captures a call's arguments as (count, ...); select("#", ...) keeps mid-list nils.
local function capture(...)
	return select("#", ...), ...
end

return {
	groupName = "Internet's Benchmark Suite: Functional Helpers",

	cases = {
		{
			name = "partial prepends stored arguments ahead of call arguments",
			func = function()
				local p = INTERNET_BENCHMARK.Functional.partial(capture, "a", "b")
				local n, a, b, c = p("c")

				expect(n).to.equal(3)
				expect(a).to.equal("a")
				expect(b).to.equal("b")
				expect(c).to.equal("c")
			end
		},

		{
			name = "partial returns the same result when called again with the same input",
			func = function()
				local p = INTERNET_BENCHMARK.Functional.partial(capture, "x")
				local n1, a1, b1 = p("y")
				local n2, a2, b2 = p("y")

				expect(n1).to.equal(n2)
				expect(a1).to.equal(a2)
				expect(b1).to.equal(b2)
			end
		},

		{
			name = "partial does not leak a longer call's extra arguments into a shorter call that follows",
			func = function()
				local p = INTERNET_BENCHMARK.Functional.partial(capture)

				local n3 = p("a", "b", "c")
				expect(n3).to.equal(3)

				local n1, a1, b1 = p("z")
				expect(n1).to.equal(1)
				expect(a1).to.equal("z")
				expect(b1).to.beNil()
			end
		},

		{
			name = "partial with no stored or call arguments passes through zero arguments",
			func = function()
				local p = INTERNET_BENCHMARK.Functional.partial(capture)
				expect(p()).to.equal(0)
			end
		},

		{
			name = "partial keeps a stored trailing nil in its own position",
			func = function()
				local p = INTERNET_BENCHMARK.Functional.partial(capture, "a", nil)
				local n, a, b, c = p("c")

				expect(n).to.equal(3)
				expect(a).to.equal("a")
				expect(b).to.beNil()
				expect(c).to.equal("c")
			end
		},

		{
			name = "partial keeps a stored leading nil in its own position",
			func = function()
				local p = INTERNET_BENCHMARK.Functional.partial(capture, nil, "b")
				local n, a, b, c = p("c")

				expect(n).to.equal(3)
				expect(a).to.beNil()
				expect(b).to.equal("b")
				expect(c).to.equal("c")
			end
		},

		{
			name = "partial leaves its stored arguments untouched between calls",
			func = function()
				local p = INTERNET_BENCHMARK.Functional.partial(capture, "a")

				local _, first = p("x", "y", "z")
				expect(first).to.equal("a")

				local n, a, b = p()
				expect(n).to.equal(1)
				expect(a).to.equal("a")
				expect(b).to.beNil()
			end
		},

		{
			name = "partial counts nil call arguments via select, not #",
			func = function()
				local p = INTERNET_BENCHMARK.Functional.partial(capture, "a")
				expect(p(nil, nil)).to.equal(3)
			end
		},

		{
			name = "flip swaps the first two arguments and leaves the rest in order",
			func = function()
				local flipped = INTERNET_BENCHMARK.Functional.flip(capture)
				local n, a, b, c, d = flipped(1, 2, 3, 4)

				expect(n).to.equal(4)
				expect(a).to.equal(2)
				expect(b).to.equal(1)
				expect(c).to.equal(3)
				expect(d).to.equal(4)
			end
		},

		{
			-- reverse_h's unbound `v` defaults to nil, and that nil is still returned as one value.
			name = "reverse of no arguments returns a single nil, not zero values",
			func = function()
				local n = select("#", INTERNET_BENCHMARK.Functional.reverse())
				expect(n).to.equal(1)
			end
		},

		{
			name = "reverse of a single argument returns exactly one value unchanged",
			func = function()
				local n, a = capture(INTERNET_BENCHMARK.Functional.reverse("only"))

				expect(n).to.equal(1)
				expect(a).to.equal("only")
			end
		},

		{
			name = "reverse flips a three-argument list end to end",
			func = function()
				local n, a, b, c = capture(INTERNET_BENCHMARK.Functional.reverse(1, 2, 3))

				expect(n).to.equal(3)
				expect(a).to.equal(3)
				expect(b).to.equal(2)
				expect(c).to.equal(1)
			end
		},

		{
			name = "reverse preserves argument count and position across a nil in the middle",
			func = function()
				local n, a, b, c = capture(INTERNET_BENCHMARK.Functional.reverse(1, nil, 3))

				expect(n).to.equal(3)
				expect(a).to.equal(3)
				expect(b).to.beNil()
				expect(c).to.equal(1)
			end
		},

		{
			name = "compose(f, g)(x) computes f(g(x)), applying the rightmost function first",
			func = function()
				local order = {}
				local function f(x) table.insert(order, "f"); return x + 1 end
				local function g(x) table.insert(order, "g"); return x * 2 end

				local composed = INTERNET_BENCHMARK.Functional.compose(f, g)

				expect(composed(3)).to.equal(7)
				expect(order[1]).to.equal("g")
				expect(order[2]).to.equal("f")
			end
		},

		{
			name = "compose with zero functions returns an identity that preserves every argument",
			func = function()
				local identity = INTERNET_BENCHMARK.Functional.compose()
				local n, a, b = capture(identity(1, 2))

				expect(n).to.equal(2)
				expect(a).to.equal(1)
				expect(b).to.equal(2)
			end
		},

		{
			name = "compose of a single function returns that function as-is",
			func = function()
				local function onlyFn(x) return x + 1 end
				expect(INTERNET_BENCHMARK.Functional.compose(onlyFn)).to.equal(onlyFn)
			end
		},

		{
			name = "compose passes every return value from one stage into the next",
			func = function()
				local function pair(x) return x, x * 10 end
				local function sum(a, b) return a + b end

				local composed = INTERNET_BENCHMARK.Functional.compose(sum, pair)
				expect(composed(3)).to.equal(33)
			end
		}
	}
}
