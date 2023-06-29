local vector1, vector2 = Vector(), Vector()

TRIAL
	:Name("Distance vs DistToSqr")
	:Before(function()
		vector1.x = math.random(-1000, 1000)
		vector1.y = math.random(-1000, 1000)
		vector1.z = math.random(-1000, 1000)

		vector2.x = math.random(-1000, 1000)
		vector2.y = math.random(-1000, 1000)
		vector2.z = math.random(-1000, 1000)
	end)
	:Function(function()
		return vector1:Distance(vector2)
	end)
	:Label("Distance")
	:Function(function()
		return vector1:DistToSqr(vector2)
	end)
	:Label("DistToSqr")
