<section class="view" data-view-section="trial:${key}">
	<div class="page">
		<header class="page-header">
			<span><button type="button" class="btn" data-view="overview">&larr; All trials</button></span>
			<h1>${title}</h1>
			<div class="tag-row">
				<span class="tag">Run count ${runs}</span>
				<span class="tag">Iterations / run ${iterations}</span>
				<span class="tag">${candidateLabel}</span>
			</div>
		</header>

		<section class="trial-hero">
			<div class="trial-hero-winner">
				<span class="trial-hero-label">Fastest</span>
				<span class="trial-hero-name">${winnerName}</span>
				<span class="trial-hero-note">${winnerNote}</span>
			</div>
			<div class="trial-hero-stats">
				<span class="trial-hero-stat">
					<span class="trial-hero-stat-label">Mean run</span>
					<span class="trial-hero-stat-value">${winnerAvg}</span>
				</span>
				<span class="trial-hero-stat">
					<span class="trial-hero-stat-label">Per call</span>
					<span class="trial-hero-stat-value">${winnerPerCall}</span>
				</span>
				<span class="trial-hero-stat">
					<span class="trial-hero-stat-label">Slowest</span>
					<span class="trial-hero-stat-value">${trialSpread}</span>
				</span>
			</div>
		</section>

		<section>
			<div class="section-head">
				<h2 class="section-title">Results</h2>
				<span class="section-note">Bars are log-scaled mean run time; percentages are relative to the fastest candidate.</span>
			</div>
			<div class="result-rows">
				${results}
			</div>
		</section>

		<section>
			<div class="section-head">
				<h2 class="section-title">Run distribution</h2>
				<div class="boxplot-legend">
					<span class="boxplot-legend-item"><span class="boxplot-swatch-box"></span>Q1&ndash;Q3</span>
					<span class="boxplot-legend-item"><span class="boxplot-swatch-median"></span>Median</span>
					<span class="boxplot-legend-item"><span class="boxplot-swatch-mean"></span>Mean</span>
				</div>
			</div>
			<div class="boxplot">
				${boxplot}
				<span class="boxplot-footnote">Logarithmic scale, ${axisMin} to ${axisMax} per run.</span>
			</div>
		</section>

		<section class="definitions-layout">
			<div class="definitions">
				<h2 class="section-title">Test definitions</h2>
				${tests}
			</div>
			<div class="predefines">
				<h2 class="section-title">Pre-definitions</h2>
				${predefines}
				<p class="predefines-note">Shared setup, run once before timing starts. Locals declared here are upvalues to every candidate in this trial.</p>
			</div>
		</section>
	</div>
</section>
