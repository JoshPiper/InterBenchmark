<section class="view active" data-view-section="overview">
	<div class="page">
		<header class="page-header">
			<span class="eyebrow">Lua micro-benchmarks</span>
			<h1>Benchmarking Report</h1>
			<p>Every trial ranks its candidates by mean run time; percentages are relative to the fastest candidate in that trial.</p>
		</header>

		<div class="tiles">
			<div class="tile">
				<span class="tile-label">Trials</span>
				<span class="tile-value">${totalTrials}</span>
			</div>
			<div class="tile">
				<span class="tile-label">Candidates</span>
				<span class="tile-value">${totalCandidates}</span>
			</div>
			<div class="tile">
				<span class="tile-label">Widest spread</span>
				<span class="tile-value">${widestSpread}</span>
				<span class="tile-note">${widestName}</span>
			</div>
			<div class="tile">
				<span class="tile-label">Ties (&lt;5%)</span>
				<span class="tile-value">${tieCount}</span>
				<span class="tile-note">no meaningful winner</span>
			</div>
		</div>

		<section class="summary-table">
			<div class="summary-head">
				<span>Trial</span>
				<span>Fastest</span>
				<span style="text-align: right;">Slowest</span>
				<span>Spread</span>
			</div>
			${rows}
		</section>
	</div>
</section>
