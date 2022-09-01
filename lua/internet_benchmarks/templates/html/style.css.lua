@import url('https://fonts.googleapis.com/css2?family=Roboto&display=swap');

html {
	font-family: Roboto, sans-serif;
	margin: 0;
	padding: 0;
}

code pre {
	padding: 4px 8px;
	display: inline-block;
	border: 2px solid #CCC;
	background: #DDD;
	border-radius: 4px;
	margin: 0;
}

table {
	border-collapse: collapse;
}

tr td, tr th {
	padding: 4px 8px;
}

tr td {
	background: #DDD;
	border: 1px solid #CCC;
}

tr th {
	background: #CCC;
}

tr td:first-child {
	font-weight: bold;
}

h2:not(:first-child){
	margin-top: 40px
}

article {
	display: none;
	margin: 0;
	padding: 8px;
}

article.active {
	display: block
}
