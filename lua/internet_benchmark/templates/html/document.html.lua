<!doctype html>
<html lang="en">
	<head>
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width, initial-scale=1">
		<title>Benchmarking Report</title>
		<link rel="stylesheet" href="style.css">
	</head>

	<body>
		<div class="layout">
			<aside class="sidebar">
				<div class="sidebar-header">
					<div class="sidebar-brand">
						<div class="sidebar-brand-text">
							<span class="sidebar-eyebrow">Benchmarking</span>
							<span class="sidebar-eyebrow-sub">Report</span>
						</div>
					</div>
					<span class="sidebar-summary">${summary}</span>
				</div>

				<nav class="sidebar-nav">
					<button type="button" class="nav-link active" data-view="overview">Overview</button>
					<button type="button" class="nav-link" data-view="environment">Environment</button>

					<span class="nav-section-label">Trials</span>

					${navTrials}
				</nav>

				<div class="sidebar-footer">
					<span class="sidebar-footer-label">Appearance</span>
					<button type="button" class="theme-toggle" data-theme-toggle>Dark</button>
				</div>
			</aside>

			<main>
				${overview}
				${environment}
				${trials}
			</main>
		</div>
	</body>

	<script src="./script.js"></script>
</html>
