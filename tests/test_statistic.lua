return function(t)
	local BENCH = INTERNET_BENCHMARK

	-- A clean spread: 1..10, 100 iterations per run.
	local stats = BENCH:Statistic({1, 2, 3, 4, 5, 6, 7, 8, 9, 10}, 100)
	t:eq(stats.count, 10, "count")
	t:eq(stats.total, 55, "total")
	t:eq(stats.mean, 5.5, "mean")
	t:eq(stats.median, 5.5, "median")
	t:eq(stats.q1, 3.5, "q1")
	t:eq(stats.q3, 7.5, "q3")
	t:eq(stats.iqr, 4, "iqr")
	t:near(stats.stdev, 2.8722813232690143, 1e-9, "stdev")
	t:eq(stats.average, 0.055, "per-call average is mean/iterations")
	t:eq(stats.min, 1, "min")
	t:eq(stats.max, 10, "max")
	t:eq(#stats.outliers, 0, "no outliers in a clean spread")

	-- Unsorted input with one extreme value.
	stats = BENCH:Statistic({9, 1, 100, 3, 7, 5, 4, 6, 2, 8}, 1)
	t:eq(stats.median, 5.5, "median ignores input order")
	t:eq(stats.q1, 3.5, "q1 with outlier")
	t:eq(stats.q3, 7.5, "q3 with outlier")
	t:eq(#stats.outliers, 1, "the extreme value is an outlier")
	t:eq(stats.outliers[1], 100, "the outlier is the extreme value")
	t:eq(stats.min, 1, "min excludes outliers")
	t:eq(stats.max, 9, "max excludes outliers")
	t:eq(stats.mean, 14.5, "mean includes outliers")

	-- Identical run times must not be rejected as outliers.
	stats = BENCH:Statistic({5, 5, 5, 5}, 1)
	t:eq(stats.median, 5, "median of identical values")
	t:eq(stats.min, 5, "min of identical values")
	t:eq(stats.max, 5, "max of identical values")
	t:eq(#stats.outliers, 0, "identical values are not outliers")

	-- A single run must produce sane statistics.
	stats = BENCH:Statistic({7}, 10)
	t:eq(stats.median, 7, "single-run median")
	t:eq(stats.q1, 7, "single-run q1")
	t:eq(stats.q3, 7, "single-run q3")
	t:eq(stats.min, 7, "single-run min")
	t:eq(stats.max, 7, "single-run max")
	t:eq(#stats.outliers, 0, "a single run is not its own outlier")
	t:near(stats.average, 0.7, 1e-12, "single-run per-call average")

	-- Degenerate input.
	t:eq(BENCH:Statistic({}, 1), nil, "empty results produce no statistics")

	-- The aggregate tracks the smallest mean for percentage columns.
	local all = BENCH:Statistics({{1, 2, 3}, {4, 5, 6}}, 10)
	t:eq(all.minMean, 2, "minMean is the smallest function mean")
	t:near(all[1].average, 0.2, 1e-12, "aggregate per-call average")
	t:eq(all[2].mean, 5, "aggregate second function mean")
end
