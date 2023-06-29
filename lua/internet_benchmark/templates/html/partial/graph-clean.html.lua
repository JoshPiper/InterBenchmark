<div id="graph-clean-${key}"></div>
<script>
	charts.set("graph-clean-${key}", new CanvasJS.Chart("graph-clean-${key}", {
		animationEnabled: false,
		theme: "light1",
		title: {text: "${title} Graphed Results"},
		height: 800,
		axisY: {
			title: "Run Timing (seconds)",
			tickLength: 0,
			gridDashType: "dash",
		},
		data: [{
			type: "boxAndWhisker",
			toolTipContent: "<span style=\"color:#6D78AD\">{label}:</span> <br><b>Maximum:</b> {y[3]},<br><b>Q3:</b> {y[2]},<br><b>Median:</b> {y[4]}<br><b>Q1:</b> {y[1]}<br><b>Minimum:</b> {y[0]}",
			// yValueFormatString: "#####.0s",
			dataPoints: [
				${data}
			]
		}, {
			type: 'error',
			dataPoints: [
				${outliers}
			]
		}]
	}))
	charts.get("graph-clean-${key}").render()
</script>
