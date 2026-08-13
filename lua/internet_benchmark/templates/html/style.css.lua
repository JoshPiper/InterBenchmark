@import url('https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;600&display=swap');

:root {
	--bg: #FCFCFF;
	--surface: #FFFFFF;
	--border: #EEEEEE;
	--ink: #10161A;
	--muted: #868F9B;
	--code: #F4F4F4;
	--accent: #28285D;
	--warn: #28285D;
	--critical: #B4483A;

	--sidebar-a: #1A1A3E;
	--sidebar-b: #28285D;
	--sidebar-ink: #FCFCFF;
	--sidebar-muted: #A9B0C4;
	--sidebar-faint: #868F9B;
	--sidebar-hover: rgba(252, 252, 255, 0.14);
	--sidebar-border: rgba(252, 252, 255, 0.14);
}

@media (prefers-color-scheme: dark) {
	:root:not([data-theme="light"]) {
		--bg: #12122B;
		--surface: #1A1A3E;
		--border: #2E2E58;
		--ink: #FCFCFF;
		--muted: #9BA3B4;
		--code: #0E0E22;
		--accent: #8B93D4;
		--warn: #8B93D4;
		--critical: #E0857A;
	}
}

:root[data-theme="dark"] {
	--bg: #12122B;
	--surface: #1A1A3E;
	--border: #2E2E58;
	--ink: #FCFCFF;
	--muted: #9BA3B4;
	--code: #0E0E22;
	--accent: #8B93D4;
	--accent-ink: #12122B;
	--warn: #8B93D4;
	--critical: #E0857A;
}

* {
	box-sizing: border-box;
}

html, body {
	margin: 0;
	padding: 0;
}

body {
	font-family: Roboto, sans-serif;
	background: var(--bg);
	color: var(--ink);
}

a {
	color: var(--accent);
}

.layout {
	display: grid;
	grid-template-columns: 300px minmax(0, 1fr);
	min-height: 100vh;
}

/* Sidebar */

.sidebar {
	background: linear-gradient(30deg, var(--sidebar-a) 50%, var(--sidebar-b) 50%);
	color: var(--sidebar-ink);
	display: flex;
	flex-direction: column;
	position: sticky;
	top: 0;
	height: 100vh;
}

.sidebar-header {
	padding: 28px 24px 20px;
	display: flex;
	flex-direction: column;
	gap: 14px;
	border-bottom: 1px solid var(--sidebar-border);
}

.sidebar-brand {
	display: flex;
	align-items: center;
	gap: 12px;
}

.sidebar-brand-text {
	display: flex;
	flex-direction: column;
	gap: 2px;
}

.sidebar-eyebrow {
	font-size: 13px;
	font-weight: 600;
	letter-spacing: 0.14em;
	text-transform: uppercase;
}

.sidebar-eyebrow-sub {
	font-size: 11px;
	letter-spacing: 0.14em;
	text-transform: uppercase;
	color: var(--sidebar-muted);
}

.sidebar-summary {
	font-size: 11px;
	color: var(--sidebar-muted);
	letter-spacing: 0.04em;
}

.sidebar-nav {
	flex: 1;
	overflow-y: auto;
	padding: 12px 12px 24px;
	display: flex;
	flex-direction: column;
	gap: 2px;
}

.nav-link {
	all: unset;
	cursor: pointer;
	display: flex;
	align-items: center;
	gap: 10px;
	padding: 10px 12px;
	border-radius: 3px;
	font-size: 12px;
	font-weight: 600;
	letter-spacing: 0.1em;
	text-transform: uppercase;
	color: var(--sidebar-ink);
}

.nav-link:hover {
	opacity: 0.8;
}

.nav-link.active {
	background: var(--sidebar-hover);
}

.nav-section-label {
	padding: 18px 12px 8px;
	font-size: 10px;
	letter-spacing: 0.16em;
	text-transform: uppercase;
	color: var(--sidebar-faint);
}

.nav-trial {
	all: unset;
	cursor: pointer;
	display: flex;
	align-items: baseline;
	justify-content: space-between;
	gap: 10px;
	padding: 9px 12px;
	border-radius: 3px;
	font-size: 12.5px;
	line-height: 1.35;
	color: var(--sidebar-muted);
}

.nav-trial:hover {
	opacity: 0.8;
}

.nav-trial.active {
	background: var(--sidebar-hover);
	color: var(--sidebar-ink);
}

.nav-trial-spread {
	font-size: 10.5px;
	font-variant-numeric: tabular-nums;
	color: var(--sidebar-faint);
	white-space: nowrap;
}

.nav-trial-spread.sev-critical {
	color: var(--critical);
}

.sidebar-footer {
	padding: 16px 20px;
	border-top: 1px solid var(--sidebar-border);
	display: flex;
	align-items: center;
	justify-content: space-between;
	gap: 12px;
}

.sidebar-footer-label {
	font-size: 10px;
	letter-spacing: 0.16em;
	text-transform: uppercase;
	color: var(--sidebar-faint);
}

.theme-toggle {
	appearance: none;
	cursor: pointer;
	border: 1px solid var(--sidebar-border);
	background: transparent;
	color: var(--sidebar-ink);
	font: inherit;
	font-size: 11px;
	font-weight: 600;
	letter-spacing: 0.08em;
	text-transform: uppercase;
	padding: 7px 14px;
	border-radius: 3px;
}

.theme-toggle:hover {
	opacity: 0.8;
}

/* Main */

main {
	min-width: 0;
}

.view {
	display: none;
}

.view.active {
	display: block;
}

.page {
	padding: 56px 56px 80px;
	max-width: 1180px;
	display: flex;
	flex-direction: column;
	gap: 40px;
}

.page-header {
	display: flex;
	flex-direction: column;
	gap: 14px;
}

.eyebrow {
	font-size: 11px;
	letter-spacing: 0.16em;
	text-transform: uppercase;
	color: var(--muted);
}

.page-header h1 {
	margin: 0;
	font-size: 42px;
	font-weight: 600;
	letter-spacing: -0.01em;
	line-height: 1.1;
}

.page-header p {
	margin: 0;
	max-width: 62ch;
	font-size: 14.5px;
	line-height: 1.65;
	color: var(--muted);
}

.section-title {
	margin: 0;
	font-size: 13px;
	font-weight: 600;
	letter-spacing: 0.16em;
	text-transform: uppercase;
	color: var(--muted);
}

.section-head {
	display: flex;
	align-items: baseline;
	justify-content: space-between;
	gap: 16px;
	flex-wrap: wrap;
}

.section-note {
	font-size: 11px;
	color: var(--muted);
}

/* Tiles */

.tiles {
	display: grid;
	grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
	gap: 16px;
}

.tile {
	border: 1px solid var(--border);
	background: var(--surface);
	padding: 20px;
	display: flex;
	flex-direction: column;
	gap: 6px;
}

.tile-label {
	font-size: 10px;
	letter-spacing: 0.16em;
	text-transform: uppercase;
	color: var(--muted);
}

.tile-value {
	font-size: 30px;
	font-weight: 600;
	font-variant-numeric: tabular-nums;
}

.tile-value.tile-value-text {
	font-size: 17px;
	line-height: 1.35;
	word-break: break-word;
}

.tile-note {
	font-size: 11.5px;
	color: var(--muted);
}

/* Overview table */

.summary-table {
	display: flex;
	flex-direction: column;
}

.summary-head {
	display: grid;
	grid-template-columns: minmax(0, 2.1fr) minmax(0, 1.5fr) 96px minmax(0, 1.6fr);
	gap: 20px;
	padding: 0 4px 10px;
	font-size: 10px;
	letter-spacing: 0.16em;
	text-transform: uppercase;
	color: var(--muted);
	border-bottom: 1px solid var(--border);
}

.summary-row {
	all: unset;
	cursor: pointer;
	display: grid;
	grid-template-columns: minmax(0, 2.1fr) minmax(0, 1.5fr) 96px minmax(0, 1.6fr);
	gap: 20px;
	align-items: center;
	padding: 14px 4px;
	border-bottom: 1px solid var(--border);
}

.summary-row:hover {
	background: var(--code);
}

.summary-name {
	display: flex;
	flex-direction: column;
	gap: 3px;
	min-width: 0;
}

.summary-name-title {
	font-size: 14px;
	font-weight: 600;
	line-height: 1.3;
}

.summary-name-sub {
	font-size: 11px;
	color: var(--muted);
}

.summary-winner {
	display: flex;
	flex-direction: column;
	gap: 3px;
	min-width: 0;
}

.summary-winner-name {
	font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
	font-size: 12.5px;
	color: var(--ink);
}

.summary-winner-sub {
	font-size: 11px;
	color: var(--muted);
	font-variant-numeric: tabular-nums;
}

.summary-spread {
	text-align: right;
	font-size: 13px;
	font-variant-numeric: tabular-nums;
	color: var(--muted);
}

.summary-spread.sev-warn {
	color: var(--warn);
}

.summary-spread.sev-critical {
	color: var(--critical);
}

.summary-bar {
	display: block;
	height: 8px;
	background: var(--code);
	position: relative;
	overflow: hidden;
}

.summary-bar > span {
	position: absolute;
	inset: 0 auto 0 0;
	background: var(--muted);
}

.summary-bar.sev-warn > span {
	background: var(--warn);
}

.summary-bar.sev-critical > span {
	background: var(--critical);
}

/* Environment */

.env-groups {
	display: grid;
	grid-template-columns: repeat(auto-fit, minmax(330px, 1fr));
	gap: 20px;
	align-items: start;
}

.env-group {
	border: 1px solid var(--border);
	background: var(--surface);
}

.env-group h2 {
	margin: 0;
	padding: 14px 20px;
	border-bottom: 1px solid var(--border);
	font-size: 11px;
	font-weight: 600;
	letter-spacing: 0.16em;
	text-transform: uppercase;
	color: var(--muted);
}

.env-group dl {
	margin: 0;
	padding: 6px 20px 16px;
	display: flex;
	flex-direction: column;
}

.env-row {
	display: grid;
	grid-template-columns: minmax(0, 1fr) minmax(0, 1.3fr);
	gap: 16px;
	padding: 11px 0;
	border-bottom: 1px solid var(--border);
	align-items: baseline;
}

.env-row:last-child {
	border-bottom: none;
}

.env-row dt {
	font-size: 12.5px;
	color: var(--muted);
}

.env-row dd {
	margin: 0;
	font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
	font-size: 12.5px;
	font-variant-numeric: tabular-nums;
	word-break: break-word;
}

/* Buttons & tags */

.btn {
	all: unset;
	cursor: pointer;
	display: inline-flex;
	align-items: center;
	gap: 6px;
	padding: 8px 16px;
	border: 1px solid var(--border);
	font-size: 12px;
	font-weight: 600;
	letter-spacing: 0.04em;
}

.btn:hover {
	opacity: 0.8;
}

.tag {
	display: inline-flex;
	align-items: center;
	padding: 6px 12px;
	border: 1px solid var(--border);
	background: var(--surface);
	font-size: 11px;
	font-weight: 600;
	letter-spacing: 0.04em;
	color: var(--muted);
}

.tag.tag-accent {
	border-color: var(--accent);
	color: var(--accent);
}

.tag-row {
	display: flex;
	flex-wrap: wrap;
	gap: 4px;
}

/* Trial view */

.trial-hero {
	border: 1px solid var(--border);
	background: linear-gradient(30deg, var(--sidebar-a) 50%, var(--sidebar-b) 50%);
	color: var(--sidebar-ink);
	padding: 30px 32px;
	display: flex;
	flex-wrap: wrap;
	align-items: flex-end;
	justify-content: space-between;
	gap: 28px;
}

.trial-hero-winner {
	display: flex;
	flex-direction: column;
	gap: 10px;
	min-width: 0;
}

.trial-hero-label {
	font-size: 10px;
	letter-spacing: 0.18em;
	text-transform: uppercase;
	color: var(--sidebar-muted);
}

.trial-hero-name {
	font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
	font-size: 28px;
	font-weight: 600;
	line-height: 1.2;
}

.trial-hero-note {
	font-size: 13px;
	color: var(--sidebar-muted);
}

.trial-hero-stats {
	display: flex;
	gap: 40px;
	flex-wrap: wrap;
}

.trial-hero-stat {
	display: flex;
	flex-direction: column;
	gap: 6px;
}

.trial-hero-stat-label {
	font-size: 10px;
	letter-spacing: 0.16em;
	text-transform: uppercase;
	color: var(--sidebar-faint);
}

.trial-hero-stat-value {
	font-size: 22px;
	font-weight: 600;
	font-variant-numeric: tabular-nums;
}

.result-rows {
	display: flex;
	flex-direction: column;
	gap: 10px;
}

.result-row {
	border: 1px solid var(--border);
	border-left: 3px solid var(--accent);
	background: var(--surface);
	padding: 16px 20px;
	display: grid;
	grid-template-columns: 26px minmax(0, 2fr) minmax(0, 1.5fr) 104px;
	gap: 20px;
	align-items: center;
}

.result-row.sev-warn {
	border-left-color: var(--warn);
}

.result-row.sev-critical {
	border-left-color: var(--critical);
}

.result-rank {
	font-size: 13px;
	font-variant-numeric: tabular-nums;
	color: var(--muted);
}

.result-name {
	display: flex;
	flex-direction: column;
	gap: 4px;
	min-width: 0;
}

.result-name-value {
	font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
	font-size: 14px;
	word-break: break-word;
}

.result-name-sub {
	font-size: 11px;
	color: var(--muted);
	font-variant-numeric: tabular-nums;
}

.result-bar {
	display: block;
	height: 10px;
	background: var(--code);
	position: relative;
	overflow: hidden;
}

.result-bar > span {
	position: absolute;
	inset: 0 auto 0 0;
	background: var(--accent);
}

.result-row.sev-warn .result-bar > span {
	background: var(--warn);
}

.result-row.sev-critical .result-bar > span {
	background: var(--critical);
}

.result-pct {
	text-align: right;
	display: flex;
	flex-direction: column;
	gap: 3px;
}

.result-pct-value {
	font-size: 18px;
	font-weight: 600;
	font-variant-numeric: tabular-nums;
}

.result-pct-sub {
	font-size: 11px;
	color: var(--muted);
	font-variant-numeric: tabular-nums;
}

.boxplot-legend {
	display: flex;
	gap: 18px;
	align-items: center;
	font-size: 11px;
	color: var(--muted);
}

.boxplot-legend-item {
	display: flex;
	align-items: center;
	gap: 6px;
}

.boxplot-swatch-box {
	width: 18px;
	height: 9px;
	background: var(--accent);
	opacity: 0.35;
}

.boxplot-swatch-median {
	width: 2px;
	height: 12px;
	background: var(--ink);
}

.boxplot-swatch-mean {
	width: 8px;
	height: 8px;
	border-radius: 50%;
	background: var(--accent);
}

.boxplot {
	border: 1px solid var(--border);
	background: var(--surface);
	padding: 26px 28px;
	display: flex;
	flex-direction: column;
	gap: 20px;
}

.boxplot-row {
	display: grid;
	grid-template-columns: 180px minmax(0, 1fr) 92px;
	gap: 18px;
	align-items: center;
}

.boxplot-row-name {
	font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
	font-size: 12px;
	color: var(--ink);
	word-break: break-word;
}

.boxplot-track {
	position: relative;
	display: block;
	height: 26px;
}

.boxplot-baseline {
	position: absolute;
	top: 50%;
	height: 1px;
	background: var(--border);
	left: 0;
	right: 0;
}

.boxplot-whisker {
	position: absolute;
	top: 50%;
	height: 1px;
	background: var(--muted);
}

.boxplot-cap {
	position: absolute;
	top: 25%;
	bottom: 25%;
	width: 1px;
	background: var(--muted);
}

.boxplot-box {
	position: absolute;
	top: 15%;
	bottom: 15%;
	min-width: 2px;
	background: var(--accent);
	opacity: 0.35;
}

.boxplot-median {
	position: absolute;
	top: 8%;
	bottom: 8%;
	width: 2px;
	background: var(--ink);
}

.boxplot-mean {
	position: absolute;
	top: 50%;
	width: 8px;
	height: 8px;
	margin: -4px 0 0 -4px;
	border-radius: 50%;
	background: var(--accent);
}

.boxplot-row-range {
	text-align: right;
	font-size: 11.5px;
	font-variant-numeric: tabular-nums;
	color: var(--muted);
}

.boxplot-footnote {
	font-size: 11px;
	color: var(--muted);
	border-top: 1px solid var(--border);
	padding-top: 14px;
}

.definitions-layout {
	display: grid;
	grid-template-columns: minmax(0, 1.55fr) minmax(0, 1fr);
	gap: 32px;
	align-items: start;
}

.definitions {
	display: flex;
	flex-direction: column;
	gap: 18px;
}

.definition {
	border: 1px solid var(--border);
	background: var(--surface);
}

.definition-head {
	padding: 12px 16px;
	border-bottom: 1px solid var(--border);
	display: flex;
	align-items: center;
	justify-content: space-between;
	gap: 12px;
}

.definition-head-name {
	font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
	font-size: 13px;
	word-break: break-word;
}

.definition-description {
	margin: 0;
	padding: 12px 16px;
	border-bottom: 1px solid var(--border);
	font-size: 12.5px;
	line-height: 1.6;
	color: var(--muted);
}

.predefines {
	display: flex;
	flex-direction: column;
	gap: 18px;
}

.predefines-note {
	margin: 0;
	font-size: 12px;
	line-height: 1.6;
	color: var(--muted);
}

pre {
	margin: 0;
	padding: 16px;
	background: var(--code);
	font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
	font-size: 12.5px;
	line-height: 1.6;
	overflow-x: auto;
	color: var(--ink);
}

pre code {
	background: none;
	border: none;
	padding: 0;
	display: inline;
}
