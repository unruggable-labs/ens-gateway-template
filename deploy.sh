#!/bin/bash
forge create \
	src/L2Contract.sol:L2Contract \
	--rpc-url "https://rpc.ankr.com/eth_sepolia" \
	--interactive \
	--etherscan-api-key $ETHERSCAN_API_KEY \
	--verify
