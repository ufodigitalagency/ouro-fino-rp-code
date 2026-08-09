Config = Config or {}

-- Ferramentas de posicionamento imprimem apenas no F8 local quando ativadas.
Config.Debug = false

-- Se true, spawna os monumentos via script (CreateObject).
-- Se false, nao spawna nada via script (usar YMAP no stream).
Config.UseScriptSpawn = true

Config.Model = "meninodaporteira"

Config.Monuments = {
    {
        id = "principal",
        enabled = true,
        position = vector3(331.972, -426.285, 44.499),
        heading = 48.36,
        zOffset = -1.200
    },
    {
        id = "praca_2",
        enabled = true,
        position = vector3(220.886, -972.807, 29.300),
        heading = 70.00,
        zOffset = -0.900
    },
    {
        id = "praca_3",
        enabled = true,
        position = vector3(-2132.704, -335.624, 13.012),
        heading = 313.97,
        zOffset = -1.100
    },
}
