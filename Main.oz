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
	FoodSpawnDelay
	FoodTimer

	CheckValidMove
	MovePlayer
	HandleMineExplosion
	SendToAllPlayers
	ChargeWeapon
	FireWeapon
	PlaceMine
	HandleBulletCollision
	GrabFlag
	DropFlag
	CheckFoodSpawn

	SpawnFood
	RandomInRange = fun {$ Min Max} Min+({OS.rand}mod(Max-Min+1)) end

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
		local NewPlayerPos OldPlayerPos in
			OldPlayerPos = {List.subtract MainState.playersPos MainState.currentPos}
			NewPlayerPos = {List.append OldPlayerPos [pt(x:NewPosX y:NewPosY)]}

			NewState = state(
				mines: MainState.mines
				flags: MainState.flags
				flag: MainState.flag
				currentPos: pt(x:NewPosX y:NewPosY)
				hp: MainState.hp
				map: MainState.map
				playersPos: NewPlayerPos
				mineReloads: MainState.mineReloads
				gunReloads: MainState.gunReloads
				food: MainState.food
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
		NewState = state(
			mines: {List.subtract State.mines mine(pos: State.currentPos)}
			flags: State.flags
			flag: State.flag
			currentPos: State.currentPos
			hp: State.hp - 2
			map: State.map
			playersPos: State.playersPos
			mineReloads: State.mineReloads
			gunReloads: State.gunReloads
			food: State.food
		)
		% GUIState
		{Send WindowPort removeMine(mine(pos: State.currentPos))} % remove mine
		{Send WindowPort lifeUpdate(ID NewState.hp)} % Update hp
		if (NewState.hp =< 0) then
			{Send WindowPort removeSoldier(ID)} % Remove player if hp dropped to 0
		end
		% PlayerState
		{SendToAllPlayers sayMineExplode(mine(pos: State.currentPos)) PlayersPorts}
		{SendToAllPlayers sayDamageTaken(ID 2 State.hp-2) PlayersPorts}
	end

	proc {ChargeWeapon ID State NewState Weapon}
		case Weapon
		of gun then
			NewState = state(
				mines: State.mines 
				flags: State.flags
				flag: State.flag
				currentPos: State.currentPos
				hp: State.hp 
				map: State.map
				playersPos: State.playersPos
				mineReloads: State.mineReloads
				gunReloads: State.gunReloads + 1
				food: State.food
			)
		[] mine then
			NewState = state(
				mines: State.mines 
				flags: State.flags
				flag: State.flag
				currentPos: State.currentPos
				hp: State.hp 
				map: State.map
				playersPos: State.playersPos
				mineReloads: State.mineReloads + 1
				gunReloads: State.gunReloads
				food: State.food
			)
		end
	end

	proc {FireWeapon ID State NewState Weapon}
		% If has enough charges, fire the corresponding weapon
		case Weapon
		of null then NewState = State
		[] gun(pos:Position) then
			% Fire gun
			if (State.gunReloads >= Input.gunCharge) andthen (Position \= State.currentPos) then
				% Alert the other players
				{SendToAllPlayers sayShoot(ID Position) PlayersPorts}

				% Check if the bullet hits something (player, mine, or nothing)
				if {List.member Position State.playersPos} then
					% Player at Position
					{HandleBulletCollision ID State Position}
					NewState = State
				elseif {List.member mine(pos:Position) State.mines} then
					% Mine at Position, trigger it
					{HandleMineExplosion ID State NewState}
				else
					% Nothing at Position
					NewState = State
				end
			else
				NewState = State
			end
		[] mine(pos:Position) then
			% Place mine
			if (State.mineReloads >= Input.mineCharge) andthen (Position == State.currentPos) then
				% Alert the other players
				{SendToAllPlayers sayMinePlaced(ID mine(pos: Position)) PlayersPorts}

				% Place mine
				{Send WindowPort putMine(mine(pos: Position))}

				% Save the new state
				NewState = state(
					mines: State.mines|mine(pos: Position)|nil
					flags: State.flags
					flag: State.flag
					currentPos: State.currentPos
					hp: State.hp 
					map: State.map
					playersPos: State.playersPos
					mineReloads: State.mineReloads - Input.mineCharge
					gunReloads: State.gunReloads
					food: State.food
				)
			else
				NewState = State
			end
		else NewState = State
		end
	end

	proc {HandleBulletCollision ID State Position}
		SoldierID
	in
		% Retrieve the ID of the player touched by the bullet
		{Send WindowPort retrieveSoldier(Position SoldierID)}

		% Player State
		{SendToAllPlayers sayDamageTaken(SoldierID 1 State.hp-1) PlayersPorts}

		% GUI Update
		{Send WindowPort lifeUpdate(SoldierID State.hp-1)}
	end

	proc {GrabFlag ID State Flag NewState}
		% Player ID grabs the Flag then alert every player
		Flags
	in
		% MainState
		{List.subtract State.flags Flag Flags}
		NewState = state(
			mines: State.mines
			flags: Flags
			flag: Flag
			currentPos: State.currentPos
			hp: State.hp
			map: State.map
			playersPos: State.playersPos
			mineReloads: State.mineReloads
			gunReloads: State.gunReloads
			food: State.food
		)

		% Players State
		{SendToAllPlayers sayFlagTaken(ID Flag) PlayersPorts}

		% GUI State
		{Send WindowPort removeFlag(Flag)}
	end

	proc {DropFlag ID State Flag NewState}
		% Player ID drops the Flag then alert every player
		% MainState
		NewState = state(
			mines: State.mines
			flags: State.flags|Flag|nil
			flag: null
			currentPos: State.currentPos
			hp: State.hp
			map: State.map
			playersPos: State.playersPos
			mineReloads: State.mineReloads
			gunReloads: State.gunReloads
			food: State.food
		)

		% Players State
		{SendToAllPlayers sayFlagTaken(ID Flag) PlayersPorts}

		% GUI State
		{Send WindowPort removeFlag(Flag)}
	end

	proc {SpawnFood FoodList NewFoodList}
		X = {RandomInRange 1 Input.nRow}
		Y = {RandomInRange 1 Input.nColumn}
	in
		if ({List.nth {List.nth Input.map X} Y} == 0) then % Nothing on this spot
			% Spawn food
			NewFoodList = FoodList|food(pos:pt(x:X y:Y))|nil
		else
			% Invalid spot, retry
			{SpawnFood FoodList NewFoodList}
		end
	end

	SimulatedThinking = proc{$} {Delay ({OS.rand} mod (Input.thinkMax - Input.thinkMin) + Input.thinkMin)} end
	RespawnTime = proc{$} {Delay Input.respawnDelay} end
	FoodSpawnDelay = ({OS.rand} mod (Input.foodDelayMax - Input.foodDelayMin) + Input.foodDelayMin)
	FoodTimer = {New Time.repeat setRepAll(delay: FoodSpawnDelay)}

	proc {Main Port ID State}
		NewState	% Final state
		MovedState	% State once player moved
		MineState	% State once player stapped on a mine
		ChargeState	% State once player charged a weapon
		FireState	% State once player fired a weapon
		GrabState	% State once player grabbed the flag
		DropState	% State once player dropped the flag
		FoodState	% State once food spawned
		ColorList = {List.take Input.colors 2} % Colors of the teams (works only if two teams, with colors stored as [a b a b ...])
		FoodList = State.food % Food List
		NewFoodList
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
				flag: State.flag
				currentPos: State.currentPos
				hp: Input.startHealth
				map: State.map
				playersPos: State.playersPos
				mineReloads: State.mineReloads
				gunReloads: State.gunReloads
				food: State.food
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

			if MineState.hp > 0 then
				% Ask the player what weapon it wants to charge
				local NewID Kind in
					{Send Port chargeItem(NewID Kind)} % Ask which weapon to charge
					{ChargeWeapon ID MineState ChargeState Kind} % Charge the corresponding weapon
					if (ChargeState.gunReloads >= Input.gunCharge) then
						{Send Port sayCharge(NewID mine)} % Inform that gun is charged
					end
					if (ChargeState.mineReloads >= Input.mineCharge) then
						{Send Port sayCharge(NewID gun)} % Inform that mine is charged
					end
				end

				% Ask the player what weapon it wants to use (if possible)
				local NewID Kind in
					{Send Port fireItem(NewID Kind)} % Ask which weapon to fire
					{FireWeapon ID ChargeState FireState Kind} % Fire the corresponding weapon
				end

				% Ask the player if he wants to grab the flag (if possible)
				local NewID Flag Color Flag Flags Test in
					% Retrieve color of enemy team
					if (ID.id == 1) then
						Color = {List.nth ColorList ID.id + 1}
					else
						Color = {List.nth ColorList ID.id - 1}
					end

					Flag = flag(color:Color pos:FireState.currentPos)
					if {List.member Flag FireState.flags} then
						% Player is on enemy flag
						% Ask if take flag
						{Send Port takeFlag(NewID Flag)}
						{GrabFlag ID FireState Flag GrabState}
					else
						GrabState = FireState
					end
				end

				% Ask the player if he wants to drop the flag (if possible)
				local NewID Flag in
					if (GrabState.flag \= null) then
						{Send Port dropFlag(NewID Flag)}
						case Flag
						of flag(color:Color pos:_) then
							{DropFlag ID GrabState Flag DropState}
						else
							DropState = GrabState
						end
					else
						DropState = GrabState
					end
				end
			else
				local NewID in
					% if player died, notify everyone and drop flag
					{SendToAllPlayers sayDeath(ID) PlayersPorts}
					if (MineState.flag \= null) then
						{Send Port dropFlag(NewID MineState.flag)}
						{DropFlag ID MineState MineState.flag DropState}
					end
				end
			end
		end

		% Check if food spawned
		% Generate Food Creation
		%{FoodTimer setRepAction({SpawnFood FoodList NewFoodList})}
		%{FoodTimer go()} % starts the loop if it is not currently running

		NewState = DropState
		{Delay 250}
		%{SimulatedThinking}
		{System.show endOfLoop(ID)}
		{Main Port ID NewState}
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
			 	{Main Port ID state(
					mines: [mine(pos: pt(x:4 y:3)) mine(pos: pt(x:4 y:2)) mine(pos: pt(x:4 y:1))]
					flags: Input.flags
					flag: null
					currentPos: Position
					hp: Input.startHealth
					map: Input.map
					playersPos: Input.spawnPoints
					mineReloads: 0
					gunReloads: 0
					food: nil
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
