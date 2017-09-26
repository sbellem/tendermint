#!/usr/bin/env bash

# XXX: removes tendermint dir
# TODO: does not work on OSX

# Get the parent directory of where this script is.
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ] ; do SOURCE="$(readlink "$SOURCE")"; done
DIR="$( cd -P "$( dirname "$SOURCE" )/../.." && pwd )"

# Change into that dir because we expect that.
cd "$DIR" || exit

# Make sure we have a tendermint command.
if ! hash tendermint 2>/dev/null; then
	make install
fi

# specify a dir to copy
# TODO: eventually we should replace with `tendermint init --test`
DIR_TO_COPY=$HOME/.tendermint_test/consensus_state_test

TMHOME="$HOME/.tendermint"
rm -rf "$TMHOME"
cp -r "$DIR_TO_COPY" "$TMHOME"
cp "$TMHOME/config.toml" "$TMHOME/config.toml.bak"

function reset(){
	tendermint unsafe_reset_all
	cp "$TMHOME/config.toml.bak" "$TMHOME/config.toml"
}

reset

# empty block
function empty_block(){
	tendermint node --proxy_app=persistent_dummy &> /dev/null &
	sleep 5
	killall tendermint

	# /q would print up to and including the match, then quit.
	# /q doesn't include the match.
	# http://unix.stackexchange.com/questions/11305/grep-show-all-the-file-up-to-the-match
	sed -e "/ENDHEIGHT: 1/Q" ~/.tendermint/data/cs.wal/wal > consensus/test_data/empty_block.cswal

	reset
}

# many blocks
function many_blocks(){
	bash scripts/txs/random.sh 1000 36657 &> /dev/null &
	PID=$!
	tendermint node --proxy_app=persistent_dummy &> /dev/null &
	sleep 10
	killall tendermint
	kill -9 $PID

	sed -e '/ENDHEIGHT: 6/Q' ~/.tendermint/data/cs.wal/wal  > consensus/test_data/many_blocks.cswal

	reset
}


# small block 1
function small_block1(){
	bash scripts/txs/random.sh 1000 36657 &> /dev/null &
	PID=$!
	tendermint node --proxy_app=persistent_dummy &> /dev/null &
	sleep 10
	killall tendermint
	kill -9 $PID

	sed -e '/ENDHEIGHT: 1/Q' ~/.tendermint/data/cs.wal/wal  > consensus/test_data/small_block1.cswal

	reset
}


# small block 2 (part size = 64)
function small_block2(){
	echo -e "\n[consensus]\nblock_part_size = 64" >> ~/.tendermint/config.toml
	bash scripts/txs/random.sh 1000 36657 &> /dev/null &
	PID=$!
	tendermint node --proxy_app=persistent_dummy &> /dev/null &
	sleep 5
	killall tendermint
	kill -9 $PID

	sed -e '/ENDHEIGHT: 1/Q' ~/.tendermint/data/cs.wal/wal  > consensus/test_data/small_block2.cswal

	reset
}



case "$1" in
	"small_block1")
		small_block1
		;;
	"small_block2")
		small_block2
		;;
	"empty_block")
		empty_block
		;;
	"many_blocks")
		many_blocks
		;;
	*)
		small_block1
		small_block2
		empty_block
		many_blocks
esac
