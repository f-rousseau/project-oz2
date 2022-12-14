functor
import
	Input
	OS
	System
export
	portPlayer:StartPlayer
define
	% Vars
	MapWidth = {List.length Input.map}
    MapHeight = {List.length Input.map.1}

	% Functions
	StartPlayer
	TreatStream
	MatchHead

	% Message functions
	InitPosition
	NewTurn
	Move
	Respawn
	AskHealth
	SayMoved
	SayMineExplode
	SayDeath
	SayDamageTaken
	SayFoodAppeared
	SayFoodEaten
	SayFlagTaken
	SayFlagDropped
	ChargeItem
	SayCharge
	FireItem
	SayMinePlaced
	SayShoot
	TakeFlag
	DropFlag
	UpdatePlayerPosition

	% Helper functions
	RandomInRange = fun {$ Min Max} Min+({OS.rand}mod(Max-Min+1)) end
in
	fun {StartPlayer Color ID}
		Stream
		Port
	in
		{NewPort Stream Port}
		thread
			{TreatStream
			 	Stream
				state(
					id: id(name:random color:Color id:ID)
					position: {List.nth Input.spawnPoints ID} % Current position
					map: Input.map
					hp: Input.startHealth % Current health
					flag: null % Current possessed flag
					mineReloads: 0 % Current mine charges
					gunReloads: 0 % Current gun charges
					startPosition: {List.nth Input.spawnPoints ID}
					% TODO You can add more elements if you need it
					flagsPos: Input.flags % Store flag positions
					minePos: nil % Store mine positions
					playerPos: nil % Store players positions
					foodPos: nil % Store food positions
				)
			}
		end
		Port
	end

    proc{TreatStream Stream State}
        case Stream
            of H|T then {TreatStream T {MatchHead H State}}
        end
    end

	fun {MatchHead Head State}
        case Head 
            of initPosition(?ID ?Position) then {InitPosition State ID Position}
            [] move(?ID ?Position) then {Move State ID Position}
            [] sayMoved(ID Position) then {SayMoved State ID Position}
            [] sayMineExplode(Mine) then {SayMineExplode State Mine}
			[] sayFoodAppeared(Food) then {SayFoodAppeared State Food}
			[] sayFoodEaten(ID Food) then {SayFoodEaten State ID Food}
			[] chargeItem(?ID ?Kind) then {ChargeItem State ID Kind}
			[] sayCharge(ID Kind) then {SayCharge State ID Kind}
			[] fireItem(?ID ?Kind) then {FireItem State ID Kind}
			[] sayMinePlaced(ID Mine) then {SayMinePlaced State ID Mine}
			[] sayShoot(ID Position) then {SayShoot State ID Position}
            [] sayDeath(ID) then {SayDeath State ID}
            [] sayDamageTaken(ID Damage LifeLeft) then {SayDamageTaken State ID Damage LifeLeft}
			[] takeFlag(?ID ?Flag) then {TakeFlag State ID Flag}
			[] dropFlag(?ID ?Flag) then {DropFlag State ID Flag}
			[] sayFlagTaken(ID Flag) then {SayFlagTaken State ID Flag}
			[] sayFlagDropped(ID Flag) then {SayFlagDropped State ID flag}
			[] respawn() then {Respawn State}
        end
    end

	%%%% TODO Message functions

	fun {InitPosition State ?ID ?Position}
		% Sets the player spawn position
		{System.show initPosition}
		ID = State.id
		Position = State.startPosition
		State
	end

	fun {Move State ?ID ?Position}
		% Decide if the player want to move
		ID = State.id
		Random = {RandomInRange 1 5}
	in
		case Random
			of 1 then
				% Move down
				Position = pt(x:State.position.x+1 y:State.position.y)
			[] 2 then
				% Move up
				Position = pt(x:State.position.x-1 y:State.position.y)
			[] 3 then
				% Move right
				Position = pt(x:State.position.x y:State.position.y+1)
			[] 4 then
				% Move left
				Position = pt(x:State.position.x y:State.position.y-1)
			else
				% Do not move
				Position = pt(x:State.position.x y:State.position.y)
		end
		State
	end

	fun {UpdatePlayerPosition PlayersPos WantedID Position ?Changed}
		case PlayersPos
		of nil then
			if Changed == false then
				player(id:WantedID pos:Position)|nil
			else
				nil
			end
		[] player(id:ID pos:_)|T then
			if (ID == WantedID) then
				player(id:WantedID pos:Position)|{UpdatePlayerPosition T WantedID Position true}
			else
				PlayersPos.1|{UpdatePlayerPosition T WantedID Position false}
			end
		end
	end

	fun {SayMoved State ID Position}
		NewPlayerPos = {UpdatePlayerPosition State.playerPos ID Position false}
	in
		% Inform the new position of player ID
		if ID == State.id then
			state(
				id:State.id
				position: Position
				map: State.map
				hp: State.hp
				flag: State.flag
				mineReloads: State.mineReloads
				gunReloads: State.gunReloads
				startPosition: State.startPosition
				flagsPos: State.flagsPos
				minePos: State.minePos
				playerPos: NewPlayerPos
			)
		else
			state(
				id:State.id
				position: State.position
				map: State.map
				hp: State.hp
				flag: State.flag
				mineReloads: State.mineReloads
				gunReloads: State.gunReloads
				startPosition: State.startPosition
				flagsPos: State.flagsPos
				minePos: State.minePos
				playerPos: NewPlayerPos
			)
		end
	end

	fun {Respawn State}
		% The player can respawn and keep playing
		{System.show respawn}
		state(
			id:State.id
			position: State.position
			map: State.map
			hp: Input.startHealth
			flag: State.flag
			mineReloads: State.mineReloads
			gunReloads: State.gunReloads
			startPosition: State.startPosition
			flagsPos: State.flagsPos
			minePos: State.minePos
			playerPos: State.playerPos
		)
	end

	fun {SayMineExplode State Mine}
		% Mine exploded somewhere
		State
	end

	fun {SayFoodAppeared State Food}
		% Food appeared somewhere
		%FoodPosition = Food.pos
		State
	end

	fun {SayFoodEaten State ID Food}
		% Player ID ate food
		State
	end

	fun {ChargeItem State ?ID ?Kind} 
		% Allow the player to choose a weapon to charge
		ID = State.id
		Random = {RandomInRange 0 1}
		NewState
	in
		case Random
			of 0 then
				Kind = gun
				NewState = state(
					id: State.id
					position: State.position
					map: State.map
					hp: State.hp
					flag: State.flag
					mineReloads: State.mineReloads
					gunReloads: State.gunReloads + 1
					startPosition: State.startPosition
					flagsPos: State.flagsPos
					minePos: State.minePos
					playerPos: State.playerPos
				)
			else
				Kind = mine
				NewState = state(
					id:State.id
					position: State.position
					map: State.map
					hp: Input.startHealth
					flag: State.flag
					mineReloads: State.mineReloads + 1
					gunReloads: State.gunReloads
					startPosition: State.startPosition
					flagsPos: State.flagsPos
					minePos: State.minePos
					playerPos: State.playerPos
				)
		end
		{System.show chargeItem(mineReloads:NewState.mineReloads gunReloads:NewState.gunReloads charged:Kind)}
		NewState
	end

	fun {SayCharge State ID Kind}
		% Inform that weapon Kind is charged
		{System.show sayCharge(State.id Kind)}
		State
	end

	fun {FireItem State ?ID ?Kind}
		% Allow the player to choose a weapon to fire
		% Fire randowmly, does not check for charges
		ID = State.id
		NewState
		RandomChoice = {RandomInRange 0 1}
		RandomXOrY = {RandomInRange 0 1}
		RandomX = {RandomInRange ~2 2}
		RandomY = {RandomInRange ~2 2}
	in
		if (RandomChoice == 0) andthen (State.gunReloads >= Input.gunCharge) then % Shoot gun
			{System.show shootGun}
			case RandomXOrY
			of 0 then 	Kind = gun(pos: pt(x:State.position.x+RandomX y:State.position.y)) % X
			else 		Kind = gun(pos: pt(x:State.position.x y:State.position.y+RandomY)) % Y
			end
			NewState = state(
				id:State.id
				position: State.position
				map: State.map
				hp: Input.startHealth
				flag: State.flag
				mineReloads: State.mineReloads
				gunReloads: State.gunReloads - Input.gunCharge
				startPosition: State.startPosition
				flagsPos: State.flagsPos
				minePos: State.minePos
				playerPos: State.playerPos
			)
		elseif (RandomChoice == 1) andthen (State.mineReloads >= Input.mineCharge) then % Place mine
			{System.show placeMine}
			Kind = mine(pos: State.position) % Place mine
			NewState = state(
				id:State.id
				position: State.position
				map: State.map
				hp: Input.startHealth
				flag: State.flag
				mineReloads: State.mineReloads - Input.mineCharge
				gunReloads: State.gunReloads
				startPosition: State.startPosition
				flagsPos: State.flagsPos
				minePos: State.minePos
				playerPos: State.playerPos
			)
		else
			{System.show doNothing}
			Kind = null
			NewState = State
		end
		NewState
	end

	fun {SayMinePlaced State ID Mine}
		% A mine as been placed by player ID
		{System.show sayMinePlaced(Mine)}
		State
	end

	fun {SayShoot State ID Position}
		% Inform that a gun has been fired toward Position by player ID
		{System.show sayShoot(Position)}
		State
	end

	fun {SayDeath State ID}
		% Inform that player ID is dead
		{System.show sayDeath(ID)}
		State
	end

	fun {SayDamageTaken State ID Damage LifeLeft}
		% Inform that player ID has taken damage and as LifeLeft hp
		{System.show damageTaken(ID damage:Damage lifeLeft:LifeLeft)}
		if ID == State.id then
			state(
				id: State.id
				position: State.position
				map: State.map
				hp: LifeLeft
				flag: State.flag
				mineReloads: State.mineReloads
				gunReloads: State.gunReloads
				startPosition: {List.nth Input.spawnPoints ID.id}
				flagsPos: State.flagsPos
				minePos: State.minePos
				playerPos: State.playerPos
			)
		else
			State
		end
    end

	fun {TakeFlag State ?ID ?Flag}
		% Decide if take flag
		ID = State.id
		Random = {RandomInRange 0 1}
	in
		{System.show takeFlag(State)}
		if Random == 1 then
			% take the flag
			Flag = true
			state(
				id: State.id
				position: State.position
				map: State.map
				hp: State.hp
				flag: Flag
				mineReloads: State.mineReloads
				gunReloads: State.gunReloads
				startPosition: State.startPosition
				flagsPos: State.flagsPos
				minePos: State.minePos
				playerPos: State.playerPos
			)
		else
			Flag = false
			State
		end
	end
			
	fun {DropFlag State ?ID ?Flag}
		% Decide if drop flag
		ID = State.id
		Random = {RandomInRange 0 1}
	in
		{System.show dropFlag}
		if Random == 1 then
			% drop the flag
			state(
				id: State.id
				position: State.position
				map: State.map
				hp: State.hp
				flag: null
				mineReloads: State.mineReloads
				gunReloads: State.gunReloads
				startPosition: State.startPosition
				flagsPos: State.flagsPos
				minePos: State.minePos
				playerPos: State.playerPos
			)
		else
			State
		end
	end

	fun {SayFlagTaken State ID Flag}
		% The player ID has picked up the flag
		{System.show sayFlagTaken(ID Flag)}
		State
	end

	fun {SayFlagDropped State ID Flag}
		% The player ID has dropped the flag
		{System.show sayFlagDropped(ID Flag)}
		State
	end
end
