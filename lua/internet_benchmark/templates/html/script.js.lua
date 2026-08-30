(function(){
	"use strict";

	var THEME_KEY = "internet_benchmark_theme";

	function applyStoredTheme(){
		var stored = null;
		try {
			stored = localStorage.getItem(THEME_KEY);
		} catch (e) {}

		if (stored === "dark" || stored === "light"){
			document.documentElement.setAttribute("data-theme", stored);
		}

		updateThemeToggleLabel();
	}

	function currentTheme(){
		var attr = document.documentElement.getAttribute("data-theme");
		if (attr === "dark" || attr === "light"){
			return attr;
		}

		return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
	}

	function updateThemeToggleLabel(){
		var toggle = document.querySelector("[data-theme-toggle]");
		if (!toggle){
			return;
		}

		toggle.textContent = currentTheme() === "dark" ? "Light" : "Dark";
	}

	function toggleTheme(){
		var next = currentTheme() === "dark" ? "light" : "dark";
		document.documentElement.setAttribute("data-theme", next);

		try {
			localStorage.setItem(THEME_KEY, next);
		} catch (e) {}

		updateThemeToggleLabel();
	}

	function setView(view){
		var sections = document.querySelectorAll("[data-view-section]");
		for (var i = 0; i < sections.length; i++){
			var match = sections[i].getAttribute("data-view-section") === view;
			sections[i].classList.toggle("active", match);
		}

		var navLinks = document.querySelectorAll("[data-view]");
		for (var j = 0; j < navLinks.length; j++){
			var match2 = navLinks[j].getAttribute("data-view") === view;
			navLinks[j].classList.toggle("active", match2);
		}
	}

	function goToView(view){
		setView(view);
		if (history.replaceState){
			history.replaceState(null, "", "#" + view);
		} else {
			location.hash = view;
		}
	}

	function viewFromHash(){
		var hash = location.hash.replace(/^#/, "");
		if (!hash){
			return "overview";
		}

		// Matched by attribute, not a built selector: an unescaped quote in a fragment throws.
		var sections = document.querySelectorAll("[data-view-section]");
		for (var i = 0; i < sections.length; i++){
			if (sections[i].getAttribute("data-view-section") === hash){
				return hash;
			}
		}

		return "overview";
	}

	document.addEventListener("click", function(event){
		var target = event.target.closest("[data-view]");
		if (target){
			goToView(target.getAttribute("data-view"));
			return;
		}

		if (event.target.closest("[data-theme-toggle]")){
			toggleTheme();
		}
	});

	window.addEventListener("hashchange", function(){
		setView(viewFromHash());
	});

	document.addEventListener("DOMContentLoaded", function(){
		applyStoredTheme();
		setView(viewFromHash());
	});
})();
