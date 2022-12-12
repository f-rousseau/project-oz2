# ----------------------------
# TODO: Fill your group number, your NOMAs and your names
# group number X
# NOMA1 : NAME1
# NOMA2 : NAME2 
# ----------------------------

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	OZC = /Applications/Mozart2.app/Contents/Resources/bin/ozc
	OZENGINE = /Applications/Mozart2.app/Contents/Resources/bin/ozengine
else
	OZC = ozc
	OZENGINE = ozengine
endif

# TODO: Change these parameters as you wish
INPUT = "Input.oz"
PLAYER1 = "PlayerBasic.oz"
PLAYER2 = "PlayerBasic.oz"

all:
	$(OZC) -c ${INPUT} -o "Input.ozf"
	$(OZC) -c ${PLAYER1} -o "Player1.ozf"
	$(OZC) -c ${PLAYER2} -o "Player2.ozf"
	$(OZC) -c PlayerManager.oz
	$(OZC) -c GUI.oz
	$(OZC) -c Main.oz
	$(OZENGINE) Main.ozf

run:
	$(OZENGINE) Main.ozf

clean:
	rm *.ozf
