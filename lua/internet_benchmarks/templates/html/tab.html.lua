<article id='${key}' class='${class}'>
	<div class='row'>
		<div class='col'>
			<h2>${title}</h2>
		</div>
	</div>

	<div class='row'>
		<h3>Trial Configuration</h3>

		<table class='table'>
			<thead class='thead'>
				<tr>
					<th>Option</th>
					<th>Value</th>
    			</tr>
			</thead>
			<tbody>
				<tr>
					<td>Run Count</td>
					<td>${runs}</td>
    			</tr>
				<tr>
					<td>Interations / Run</td>
					<td>${iterations}</td>
    			</tr>
			</tbody>
		</table>
	</div>

	<div class='row'>
		<div class='col'>
			<h3>Test Definitions</h3>
			${tests}
		</div>

		<div class='col'>
			<h3>Pre-Definitions</h3>
			${predefines}
		</div>
	</div>

	<div class='row'>
		<div class='col'>
			<h3>Results</h3>
			${content}
		</div>
	</div>
</article>
