local ZSTATES = {}

ZSTATES.NONE = "" -- il ne fait rien !
ZSTATES.WALK = "walk" -- il rôde
ZSTATES.ATTACK = "attack" -- il attaque
ZSTATES.JOIN = "join" -- il rejoins un camarade
ZSTATES.BITE = "bite" -- il mord !
ZSTATES.CHANGE = "changedirection" -- il change de direction

return ZSTATES