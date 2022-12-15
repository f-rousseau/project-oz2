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

	CheckValidMove
	MovePlayer
	HandleMineExplosion
	SendToAllPlayers

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
				currentPos: pt(x:NewPosX y:NewPosY)
				hp: MainState.hp 
				map: MainState.map
				playersPos: NewPlayerPos
				)
		end
		% PlayerState
		{SendToAllPlayers sayMoved(ID pt(x:NewPosX y:NewPosY)) PlayersPorts}
		% GUIState
		{Send WindowPort moveSoldier(ID pt(x:NewPosX y:NewPosY))}
	end

	proc {HandleMineExplosion ID State}
		% must notify the 3 components : MainState, GUIState and PlayerState
		% MainState
		{System.show mainStateUpdate}
		% GUIState
		{Send WindowPort removeMine(mine(pos: State.currentPos))}
		% PlayerState
		{SendToAllPlayers sayMineExplode(mine(pos: State.currentPos)) PlayersPorts}
		{SendToAllPlayers sayDamageTaken(ID 2 State.hp-2) PlayersPorts}
		
		{Send WindowPort lifeUpdate(ID State.hp-2)}
	end

	SimulatedThinking = proc{$} {Delay ({OS.rand} mod (Input.thinkMax - Input.thinkMin) + Input.thinkMin)} end

	proc {Main Port ID State}
		local NewState in
			{System.show startOfLoop(ID)}

			% check if dead 
			if State.hp < 0 then
				{System.show mustRespawn}
				% respawn
			end

			% check if player moved on a mine
			if {List.member mine(pos:State.currentPos) State.mines} then
				{HandleMineExplosion ID State NewState}
				%Handle NewState conflicts
			end

			% ask where the player wants to move and mvoe it if possible
			local NewID AskPos R in
				{Send Port move(NewID AskPos)}
				if {CheckValidMove ID State.currentPos AskPos.x AskPos.y State.map State.playersPos} then
					{MovePlayer ID Port State NewState AskPos.x AskPos.y}
				else
					NewState = State
				end
			end



			{Delay 250}
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
			 	{Main Port ID state(

					mines: [mine(pos: pt(x:4 y:3)) mine(pos: pt(x:4 y:1)) mine(pos: pt(x:4 y:1))]


					flags:Input.flags 
					currentPos: Position 
					hp:Input.startHealth 
					map:Input.map
					playersPos:Input.spawnPoints
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
