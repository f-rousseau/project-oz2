functor
export
    nRow:NRow
    nColumn:NColumn
    map:Map
    players:Players
    colors:Colors
    guiDelay:GUIDelay
    nbPlayer:NbPlayer
    startHealth:StartHealth
    thinkMin:ThinkMin
    thinkMax:ThinkMax
    foodDelayMin:FoodDelayMin
    foodDelayMax:FoodDelayMax
    gunCharge:GunCharge
    mineCharge:MineCharge
    respawnDelay:RespawnDelay
    spawnPoints:SpawnPoints
    flags:Flags
define
    NRow
    NColumn
    Map
    Players
    Colors
    NbPlayer
    StartHealth
    GUIDelay
    ThinkMin
    ThinkMax
    FoodDelayMin
    FoodDelayMax
    GunCharge
    MineCharge
    RespawnDelay
    SpawnPoints
    Flags
in

%%%% Description of the map %%%%

    NRow = 12
    NColumn = 12

    % 0 = Empty
    % 1 = Player 1's base
    % 2 = Player 2's base
    % 3 = Walls

    Map = [[1 1 1 0 0 0 0 0 0 0 0 0]
	       [1 1 1 0 0 0 0 0 0 0 0 0]
	       [0 0 0 0 0 0 0 0 0 0 0 0]
	       [0 0 0 3 3 0 0 3 3 0 0 0]
	       [0 0 0 3 0 0 0 0 3 0 0 0]
	       [0 0 0 0 0 0 0 0 0 0 0 0]
	       [0 0 0 0 0 0 0 0 0 0 0 0]
	       [0 0 0 3 0 0 0 0 3 0 0 0]
           [0 0 0 3 3 0 0 3 3 0 0 0]
           [0 0 0 0 0 0 0 0 0 0 0 0]
	       [0 0 0 0 0 0 0 0 0 2 2 2]
	       [0 0 0 0 0 0 0 0 0 2 2 2]]

%%%% Players description %%%%

    Players = [player1 player2 player1 player2 player1 player2]
    Colors = [red blue red blue red blue]
    SpawnPoints = [pt(x:1 y:1) pt(x:12 y:10) pt(x:1 y:2) pt(x:12 y:11) pt(x:1 y:3) pt(x:12 y:12)]
    NbPlayer = 6
    StartHealth = 2

%%%% Waiting time for the GUI between each effect %%%%

    GUIDelay = 500 % ms

%%%% Thinking parameters %%%%

    ThinkMin = 450
    ThinkMax = 500

%%%% Food apparition parameters %%%%

    FoodDelayMin = 25000
    FoodDelayMax = 30000

%%%% Charges
    GunCharge = 1
    MineCharge = 5
     
%%%% Respawn
    RespawnDelay = 25000

%%%% Flags
    Flags = [flag(pos:pt(x:3 y:4) color:red) flag(pos:pt(x:10 y:9) color:blue)]

end
