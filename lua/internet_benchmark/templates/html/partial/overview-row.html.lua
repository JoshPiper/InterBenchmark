<button type="button" class="summary-row" data-view="trial:${key}">
	<span class="summary-name">
		<span class="summary-name-title">${name}</span>
		<span class="summary-name-sub">${countLabel}</span>
	</span>
	<span class="summary-winner">
		<span class="summary-winner-name">${winner}</span>
		<span class="summary-winner-sub">${winnerPerCall} / call</span>
	</span>
	<span class="summary-spread ${spreadClass}">${spread}</span>
	<span class="summary-bar ${spreadClass}">
		<span style="width: ${barW}%;"></span>
	</span>
</button>
