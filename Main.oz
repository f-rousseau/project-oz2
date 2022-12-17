functor
import
	GUI
	Input
	PlayerManager
	System
	OS
define
	DoListPlayer
	InitThreadForAll
	PlayersPorts
	SimulatedThinking
	Main
	WindowPort
	RespawnTime

	CheckValidMove
	MovePlayer
	HandleMineExplosion
	SendToAllPlayers
	ChargeWeapon
	FireWeapon
	PlaceMine
	HandleBulletCollision

	proc {DrawFlags Flags Port}
		case Flags of nil then skip 
		[] Flag|T then
			{Send Port putFlag(Flag)}
			{DrawFlags T Port}
		end
	end
in
    fun {DoListPlayer Players Colors ID}
		case Players#Colors
		of nil#nil then nil
		[] (Player|NextPlayers)#(Color|NextColors) then
			player(ID {PlayerManager.playerGenerator Player Color ID})|
			{DoListPlayer NextPlayers NextColors ID+1}
		end
	end

	proc {SendToAllPlayers Request PlayersList}
		case PlayersList of nil then skip
		[] Player|Next then
			{Send Player.2 Request}
			{SendToAllPlayers Request Next}
		end
	end

	fun {CheckValidMove ID CurPos AskPosX AskPosY Map PlayersPos}
		% todo check if player is already there

		% player already here
		if {List.member pt(x:AskPosX y:AskPosY) PlayersPos} then
			false
		% check for only one direction and one tile
		elseif {Number.abs CurPos.y - AskPosY} == 1  andthen {Number.abs CurPos.x - AskPosX} == 0 then
			%check if not out of bound
			if AskPosY =< Input.nColumn andthen AskPosY > 0 then
				% check if empty
				if {List.nth {List.nth Map AskPosX} AskPosY} == 0 then
					true
				% check if not ennemy base
				elseif {List.nth {List.nth Map AskPosX} AskPosY} == 1 then
					if {Int.'mod' ID.id 2} \= 0 then
						true
					else
						false
					end
				elseif {List.nth {List.nth Map AskPosX} AskPosY} == 2 then
					if {Int.'mod' ID.id 2} == 0 then
						true
					else
						false
					end
				else
					false
				end
			else
				false
			end
		elseif {Number.abs CurPos.y - AskPosY} == 0  andthen {Number.abs CurPos.x - AskPosX} == 1 then
			if AskPosX =< Input.nRow andthen AskPosX > 0 then
				if {List.nth {List.nth Map AskPosX} AskPosY} == 0 then
					true
				elseif {List.nth {List.nth Map AskPosX} AskPosY} == 1 then
					if {Int.'mod' ID.id 2} \= 0 then
						true
					else
						false
					end
				elseif {List.nth {List.nth Map AskPosX} AskPosY} == 2 then
					if {Int.'mod' ID.id 2} == 0 then
						true
					else
						false
					end
				else
					false
				end
				
			else
				false
			end
		else
			false
		end
	end

	proc {MovePlayer ID Port MainState NewState NewPosX NewPosY}
		% must update the 3 components : MainState, GUIState and PlayerState
		% MainState
		local NewPlayerPos OldPlayerPos Orientation in
			OldPlayerPos = {List.subtract MainState.playersPos MainState.currentPos}
			NewPlayerPos = {List.append OldPlayerPos [pt(x:NewPosX y:NewPosY)]}

			% 0 = up, 1 = right, 2 = down, 3 = left (changes with every movement)
			if NewPosY - MainState.currentPos.y > 0 then
				Orientation = 1 % player moved right
			elseif NewPosY - MainState.currentPos.y < 0 then
				Orientation = 3 % player moved left
			elseif NewPosX - MainState.currentPos.x > 0 then
				Orientation = 2 % player moved down
			elseif NewPosX - MainState.currentPos.x < 0 then
				Orientation = 0 % player moved up
			else
				Orientation = MainState.orientation % Did not move, orientation stays the same
			end

			NewState = state(
				mines: MainState.mines 
				flags: MainState.flags 
				currentPos: pt(x:NewPosX y:NewPosY)
				hp: MainState.hp 
				map: MainState.map
				playersPos: NewPlayerPos
				mineReloads: MainState.mineReloads
				gunReloads: MainState.gunReloads
				orientation: Orientation
				)
		end
		% PlayerState
		{SendToAllPlayers sayMoved(ID pt(x:NewPosX y:NewPosY)) PlayersPorts}
		% GUIState
		{Send WindowPort moveSoldier(ID pt(x:NewPosX y:NewPosY))}
	end

	proc {HandleMineExplosion ID State NewState}
		% must notify the 3 components : MainState, GUIState and PlayerState
		% MainState
		{System.show mainStateUpdate}
		NewState = state(
			mines: State.mines 
			flags: State.flags 
			currentPos: State.currentPos
			hp: State.hp - 2
			map: State.map
			playersPos: State.playersPos
			mineReloads: State.mineReloads
			gunReloads: State.gunReloads
			orientation: State.orientation
			)
		% GUIState
		{Send WindowPort removeMine(mine(pos: State.currentPos))}
		% PlayerState
		{SendToAllPlayers sayMineExplode(mine(pos: State.currentPos)) PlayersPorts}
		{SendToAllPlayers sayDamageTaken(ID 2 State.hp-2) PlayersPorts}

		{Send WindowPort lifeUpdate(ID State.hp-2)}
	end

	proc {ChargeWeapon ID MainState NewState Weapon}
		case Weapon
		of gun then
			NewState = state(
				mines: MainState.mines 
				flags: MainState.flags 
				currentPos: MainState.currentPos
				hp: MainState.hp 
				map: MainState.map
				playersPos: MainState.playersPos
				mineReloads: MainState.mineReloads
				gunReloads: MainState.gunReloads + 1
				orientation: MainState.orientation
				)
		[] mine then
			NewState = state(
				mines: MainState.mines 
				flags: MainState.flags 
				currentPos: MainState.currentPos
				hp: MainState.hp 
				map: MainState.map
				playersPos: MainState.playersPos
				mineReloads: MainState.mineReloads + 1
				gunReloads: MainState.gunReloads
				orientation: MainState.orientation
				)
		end
	end

	proc {FireWeapon ID MainState NewState Kind}
		% If has enough charges, fire the corresponding weapon	
		case Kind
		of gun then
			% Fire gun
			if MainState.gunReloads >= Input.gunCharge then
				% Shoot check if there is a target (player on mine) on the trajectory of the bullet
				local TouchedPlayer Case1 Case2 CurrentState MineExploded in
					% 0 = up, 1 = right, 2 = down, 3 = left
					case MainState.orientation
					of 0 then % up
						Case1 = pt(MainState.currentPos.x - 1 MainState.currentPos.y) % one case up
						if {List.member Case1 MainState.playersPos} then
							% Player at position
							TouchedPlayer = {List.subtract MainState.playersPos Case1}
							{System.show TouchedPlayer}
							MineExploded = 0
						elseif {List.member mine(pos:Case1) MainState.mines} then
							% Mine at position, trigger it
							{HandleMineExplosion ID MainState CurrentState}
							MineExploded = 1
						else
							Case2 = pt(MainState.currentPos.x - 2 MainState.currentPos.y) % two cases up
							if {List.member Case2 MainState.playersPos} then
								% Player at position
								TouchedPlayer = {List.subtract MainState.playersPos Case2}
								{System.show TouchedPlayer}
								MineExploded = 0
							elseif {List.member mine(pos:Case2) MainState.mines} then
								% Mine at position, trigger it
								{HandleMineExplosion ID MainState CurrentState}
								MineExploded = 1
							end
						end
					[] 1 then % right
						Case1 = pt(MainState.currentPos.x MainState.currentPos.y + 1) % one case right
						if {List.member Case1 MainState.playersPos} then
							% Player at position
							TouchedPlayer = {List.subtract MainState.playersPos Case1}
							{System.show TouchedPlayer}
							MineExploded = 0
						elseif {List.member mine(pos:Case1) MainState.mines} then
							% Mine at position, trigger it
							{HandleMineExplosion ID MainState CurrentState}
							MineExploded = 1
						else
							Case2 = pt(MainState.currentPos.x - 2 MainState.currentPos.y) % two cases right
							if {List.member Case2 MainState.playersPos} then
								% Player at position
								TouchedPlayer = {List.subtract MainState.playersPos Case2}
								{System.show TouchedPlayer}
								MineExploded = 0
							elseif {List.member mine(pos:Case2) MainState.mines} then
								% Mine at position, trigger it
								{HandleMineExplosion ID MainState CurrentState}
								MineExploded = 1
							end
						end
					[] 2 then % down
						Case1 = pt(MainState.currentPos.x + 1 MainState.currentPos.y) % one case down
						if {List.member Case1 MainState.playersPos} then
							% Player at position
							TouchedPlayer = {List.subtract MainState.playersPos Case1}
							{System.show TouchedPlayer}
							MineExploded = 0
						elseif {List.member mine(pos:Case1) MainState.mines} then
							% Mine at position, trigger it
							{HandleMineExplosion ID MainState CurrentState}
							MineExploded = 1
						else
							Case2 = pt(MainState.currentPos.x - 2 MainState.currentPos.y) % two cases down
							if {List.member Case2 MainState.playersPos} then
								% Player at position
								TouchedPlayer = {List.subtract MainState.playersPos Case2}
								{System.show TouchedPlayer}
								MineExploded = 0
							elseif {List.member mine(pos:Case2) MainState.mines} then
								% Mine at position, trigger it
								{HandleMineExplosion ID MainState CurrentState}
								MineExploded = 1
							end
						end
					[] 3 then % left
						Case1 = pt(MainState.currentPos.x MainState.currentPos.y - 1) % one case left
						if {List.member Case1 MainState.playersPos} then
							% Player at position
							TouchedPlayer = {List.subtract MainState.playersPos Case1}
							{System.show TouchedPlayer}
							MineExploded = 0
						elseif {List.member mine(pos:Case1) MainState.mines} then
							% Mine at position, trigger it
							{HandleMineExplosion ID MainState CurrentState}
							MineExploded = 1
						else
							Case2 = pt(MainState.currentPos.x - 2 MainState.currentPos.y) % two cases left
							if {List.member Case2 MainState.playersPos} then
								% Player at position
								TouchedPlayer = {List.subtract MainState.playersPos Case2}
								{System.show TouchedPlayer}
								MineExploded = 0
							elseif {List.member mine(pos:Case2) MainState.mines} then
								% Mine at position, trigger it
								{HandleMineExplosion ID MainState CurrentState}
								MineExploded = 1
							end
						end
					end
					% Alert the other players
					{SendToAllPlayers sayShoot(ID MainState.currentPos) PlayersPorts}

					% Save the new state
					/*if MineExploded == 1 then %TODO
						NewState = state(
							mines: CurrentState.mines % Save new mines
							flags: MainState.flags 
							currentPos: MainState.currentPos
							hp: MainState.hp 
							map: MainState.map
							playersPos: MainState.playersPos
							mineReloads: MainState.mineReloads
							gunReloads: MainState.gunReloads - Input.gunCharge
							orientation: MainState.orientation
						)
					else
						NewState = state(
							mines: MainState.mines
							flags: MainState.flags 
							currentPos: MainState.currentPos
							hp: MainState.hp 
							map: MainState.map
							playersPos: MainState.playersPos
							mineReloads: MainState.mineReloads
							gunReloads: MainState.gunReloads - Input.gunCharge
							orientation: MainState.orientation
						)
					end*/
					NewState = state(
						mines: MainState.mines
						flags: MainState.flags 
						currentPos: MainState.currentPos
						hp: MainState.hp 
						map: MainState.map
						playersPos: MainState.playersPos
						mineReloads: MainState.mineReloads
						gunReloads: MainState.gunReloads - Input.gunCharge
						orientation: MainState.orientation
					)
				end
			else
				NewState = MainState
			end
		[] mine then
			% Place mine
			if MainState.mineReloads >= Input.mineCharge then
				local
					Mine = mine(pos: MainState.currentPos)
				in
					% Alert the other players
					{SendToAllPlayers sayMinePlaced(ID Mine) PlayersPorts}

					% Place mine
					{Send WindowPort putMine(Mine)}

					% Save the new state
					NewState = state(
						mines: {List.append MainState.mines [Mine]}
						flags: MainState.flags 
						currentPos: MainState.currentPos
						hp: MainState.hp 
						map: MainState.map
						playersPos: MainState.playersPos
						mineReloads: MainState.mineReloads - Input.mineCharge
						gunReloads: MainState.gunReloads
						orientation: MainState.orientation
						)
				end
			else
				NewState = MainState
			end
		end
	end

	proc {HandleBulletCollision ID State}
		% Player State
		{SendToAllPlayers sayDamageTaken(ID 1 State.hp-1) PlayersPorts}

		% GUI Update
		{Send WindowPort lifeUpdate(ID State.hp-1)}
	end

	SimulatedThinking = proc{$} {Delay ({OS.rand} mod (Input.thinkMax - Input.thinkMin) + Input.thinkMin)} end
	RespawnTime = proc{$} {Delay Input.respawnDelay} end

	proc {Main Port ID State}
		local
			NewState
			MovedState
			MineState
			ChargeState
			FireState
			MineState
		in
			{System.show startOfLoop(ID)}

			if State.hp =< 0 then
				% Player is dead, wait for respawn and skip the rest of the turn
				% GUI State
				{Send WindowPort removeSoldier(ID)}
				% PlayerState
				{SendToAllPlayers sayDeath(ID) PlayersPorts}
				{RespawnTime}
				% GUI State
				{Send WindowPort initSoldier(ID State.currentPos)}
				{Send WindowPort lifeUpdate(ID Input.startHealth)}
				% Respawn
				{Send Port respawn()}
				% Main State
				NewState = state(
					mines: State.mines 
					flags: State.flags 
					currentPos: State.currentPos
					hp: Input.startHealth
					map: State.map
					playersPos: State.playersPos
					mineReloads: State.mineReloads
					gunReloads: State.gunReloads
					orientation: State.orientation
					)
			else
				% ask where the player wants to move and move it if possible
				local NewID AskPos R in
					{Send Port move(NewID AskPos)}
					if {CheckValidMove ID State.currentPos AskPos.x AskPos.y State.map State.playersPos} then
						{MovePlayer ID Port State MovedState AskPos.x AskPos.y}
					else
						MovedState = State
					end
				end

				% check if player moved on a mine
				if {List.member mine(pos:MovedState.currentPos) State.mines} then
					{HandleMineExplosion ID MovedState MineState}
					% Handle NewState conflicts
				else
					MineState = MovedState
				end

				if State.hp > 0 then
					% ask the player what weapon it wants to charge
					local NewId Kind in
						{Send Port chargeItem(NewId Kind)} % Ask which weapon to charge
						{ChargeWeapon ID MineState ChargeState Kind}
						%NewState = ChargeState
					end

					% ask the player what weapon it wants to use (if possible)
					local NewId Kind in
						{Send Port fireItem(NewId Kind)} % Ask which weapon to fire
						{FireWeapon ID ChargeState FireState Kind}
						NewState = FireState
					end

					% ask the player if he wants to grab the flag (if possible)

					% ask the player if he wants to drop the flag (if possible)

				%else
					% if player died, notify everyone and drop flag
				end
			end

			% spawn food if possible

			{Delay 250}
			%{SimulatedThinking}
			{System.show endOfLoop(ID)}
			{Main Port ID NewState}
		end
	end

	proc {InitThreadForAll Players}
		case Players
		of nil then
			{Send WindowPort initSoldier(null pt(x:0 y:0))}


			{Send WindowPort putMine(mine(pos: pt(x:4 y:3)))}
			{Send WindowPort putMine(mine(pos: pt(x:4 y:2)))}
			{Send WindowPort putMine(mine(pos: pt(x:4 y:1)))}


			{DrawFlags Input.flags WindowPort}
		[] player(_ Port)|Next then ID Position in
			{Send Port initPosition(ID Position)}
			{Send WindowPort initSoldier(ID Position)}
			{Send WindowPort lifeUpdate(ID Input.startHealth)}
			thread
				% Orientation : 0 = up, 1 = right, 2 = down, 3 = left (changes with every movement)
			 	{Main Port ID state(

					mines: [mine(pos: pt(x:4 y:3)) mine(pos: pt(x:4 y:2)) mine(pos: pt(x:4 y:1))]


					flags: Input.flags 
					currentPos: Position 
					hp: Input.startHealth 
					map: Input.map
					playersPos: Input.spawnPoints
					mineReloads: 0
					gunReloads: 0
					orientation: 0 
					)}
			end
			{InitThreadForAll Next}
		end
	end

    thread
		% Create port for window
		WindowPort = {GUI.portWindow}

		% Open window
		{Send WindowPort buildWindow}
		{System.show buildWindow}

        % Create port for players
		PlayersPorts = {DoListPlayer Input.players Input.colors 1}

		{InitThreadForAll PlayersPorts}
	end
end
