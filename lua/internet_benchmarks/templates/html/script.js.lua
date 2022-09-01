window.tabs = {
	set: function(id){
		$("article").hide()
		$("#" + id).show()
	},

	bind: function(){
		$("header li").click(function(){
			tabs.set($(this).children().first().attr("x-tab"))
			$(this).siblings().removeClass("active")
			$(this).addClass("active")
		})
	}
}

$(document).ready(function(){
	tabs.bind()

	let active = $("li.active")
	console.log(active)
	// Set either the one marked as active.
	// Or if none are, fall back to the first sidebar element.
	if (active.length === 0){
		active = $("header li").first()
	} else {
		active = active.first()
	}

	tabs.set(active.children().first().attr("x-tab"))
})
