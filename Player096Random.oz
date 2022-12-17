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
	PlayersPosition
	IsDead = 0
	FoodPosition

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
					position: {List.nth Input.spawnPoints ID}
					map: Input.map
					hp: Input.startHealth
					flag: null
					mineReloads: 0
					gunReloads: 0
					startPosition: {List.nth Input.spawnPoints ID}
					% TODO You can add more elements if you need it
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
		if IsDead == 0 then
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
		end
		State
	end

	fun {SayMoved State ID Position}
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
			)
		else
			State
		end
	end

	fun {Respawn State}
		% The player can respawn and keep playing
		{System.show respawn}
		IsDead := 0
		state(
			id:State.id
			position: State.position
			map: State.map
			hp: Input.startHealth
			flag: State.flag
			mineReloads: State.mineReloads
			gunReloads: State.gunReloads
			startPosition: State.startPosition
		)
	end

	fun {SayMineExplode State Mine}
		% Mine exploded somewhere
		State
	end

	fun {SayFoodAppeared State Food}
		% Food appeared somewhere
		FoodPosition = Food.pos
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
	in
		case Random
			of 0 then Kind = gun
			else Kind = mine
		end
		State
	end

	fun {SayCharge State ID Kind}
		% Inform that weapon Kind is charged
		{System.show sayCharge}
		State
	end

	fun {FireItem State ?ID ?Kind}
		% Allow the player to choose a weapon to fire
		ID = State.id
		Kind = null
		Random = {RandomInRange 0 1}
	in
		{System.show fireItem}
		State
	end

	fun {SayMinePlaced State ID Mine}
		% A mine as been placed by player ID
		{System.show sayMinePlaced}
		State
	end

	fun {SayShoot State ID Position}
		% Inform that a gun has been fired toward Position by player ID
		{System.show sayShoot}
		State
	end

	fun {SayDeath State ID}
		% Inform that player ID is dead
		if ID == State.id then
			{System.show isDead}
			IsDead := 1
		end
		State
	end

	fun {SayDamageTaken State ID Damage LifeLeft}
		% Inform that player ID has taken damage and as LifeLeft hp
		if ID == State.id then
			{System.show damageTaken}
			state(
				id: State.id
				position: State.position
				map: State.map
				hp: LifeLeft
				flag: State.flag
				mineReloads: State.mineReloads
				gunReloads: State.gunReloads
				startPosition: {List.nth Input.spawnPoints ID.id}
			)
		else
			State
		end
    end

	fun {TakeFlag State ?ID ?Flag}
		% Decide if take flag
		ID = State.id
		Flag = State.flag
		Random = {RandomInRange 0 1}
	in
		{System.show takeFlag}
		if Random == 1 then
			% take the flag
			state(
				id: State.id
				position: State.position
				map: State.map
				hp: State.hp
				flag: Flag
				mineReloads: State.mineReloads
				gunReloads: State.gunReloads
				startPosition: State.startPosition
			)
		else
			State
		end
	end
			
	fun {DropFlag State ?ID ?Flag}
		% Decide if drop flag
		ID = State.id
		Flag = State.flag
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
				flag: Flag
				mineReloads: State.mineReloads
				gunReloads: State.gunReloads
				startPosition: State.startPosition
			)
		else
			State
		end
	end

	fun {SayFlagTaken State ID Flag}
		% The player ID has picked up the flag
		{System.show sayFlagTaken}
		State
	end

	fun {SayFlagDropped State ID Flag}
		% The player ID has dropped the flag
		{System.show sayFlagDropped}
		State
	end
end
