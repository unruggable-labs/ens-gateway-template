//SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// https://sepolia.etherscan.io/address/0x83fc17a94115ae805f7c251635363eed5180fdae#code

contract L2DataContract {
    // address slot0 = 0x9e837209b30C9cC23fA22d0E5DbE3776db8FCe7F;

    mapping(bytes32 hashname => address resolvedAddress) public nodes;

    function register(string calldata name, address _addr) public {
        bytes32 node = keccak256(abi.encode(name));
        nodes[node] = _addr;
    }

    // function addr(bytes32 node) public view returns (address) {
    //     return nodes[node];
    // }
}
