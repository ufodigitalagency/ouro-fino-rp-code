-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
-----------------------------------------------------------------------------------------------------------------------------------------
local Services = {
	{
		Permission = "Paramedico",
		Coords = vec3(-678.4653,326.4574,83.2539),
		Distance = 1.5,
		Weight = 0.35
	},{
		Permission = "Policia",
		Coords = vec3(-433.3145,1099.7092,327.9403),
		Distance = 1.5,
		Weight = 0.35
	}
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- VARIANTS
-----------------------------------------------------------------------------------------------------------------------------------------
local Variants = {
	LSPD = "Policia",
	SAPR = "Policia",
	BCSO = "Policia"
}
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSERVICE
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	for Index,v in pairs(Services) do
		exports.target:AddCircleZone("Service:"..Index,v.Coords,v.Weight,{
			name = "Service:"..Index,
			heading = 0.0,
			useZ = true
		},{
			Distance = v.Distance,
			options = {
				{
					event = "target:Service",
					label = "Iniciar Expediente",
					service = v.Permission,
					tunnel = "proserver"
				}
			}
		})
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- SERVICE:CLIENT
-----------------------------------------------------------------------------------------------------------------------------------------
RegisterNetEvent("service:Client")
AddEventHandler("service:Client",function(Permission,Status)
	for Index,v in pairs(Services) do
		if (Variants[Permission] and Variants[Permission] == v.Permission) or Permission == v.Permission then
			exports.target:LabelText("Service:"..Index,(Status and "Finalizar Expediente" or "Iniciar Expediente"))
		end
	end
end)
