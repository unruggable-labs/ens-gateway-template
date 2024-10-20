// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {GatewayFetcher, GatewayRequest} from "@unruggable/gateways/contracts/GatewayFetcher.sol";
import {GatewayFetchTarget, IGatewayVerifier} from "@unruggable/gateways/contracts/GatewayFetchTarget.sol";

interface IERC165 {
    function supportsInterface(bytes4 x) external view returns (bool);
}

interface IExtendedResolver {
    function resolve(
        bytes calldata name,
        bytes calldata data
    ) external view returns (bytes memory);
}

interface IAddrResolver {
    function addr(bytes32 node) external view returns (address);
}

interface IAddressResolver {
    function addr(
        bytes32 node,
        uint256 coinType
    ) external view returns (address);
}

contract L1SimpleResolver is GatewayFetchTarget, IERC165, IExtendedResolver {
    using GatewayFetcher for GatewayRequest;

    IGatewayVerifier public immutable verifier;
    address public immutable l2TargetAddress;

    constructor(address _verifier, address _l2TargetAddress) {
        verifier = IGatewayVerifier(_verifier);
        l2TargetAddress = _l2TargetAddress;
    }

    function supportsInterface(bytes4 x) external pure returns (bool) {
        return
            x == type(IERC165).interfaceId ||
            x == type(IExtendedResolver).interfaceId;
    }

    function resolve(
        bytes calldata name,
        bytes calldata data
    ) external view returns (bytes memory) {
        GatewayRequest memory r = GatewayFetcher.newRequest(1).setTarget(
            l2TargetAddress
        );
        // NOTE: https://sepolia.etherscan.io/address/0x83fc17a94115ae805f7c251635363eed5180fdae#code
        // is storing values under keccak(abi.encode(label))
        bytes memory label = name[1:1 + uint8(name[0])];
        bytes32 l2Node = keccak256(abi.encode(label));
        // check if its a request we understand
        if (
            bytes4(data) == IAddrResolver.addr.selector ||
            bytes4(data) == IAddressResolver.addr.selector
        ) {
            r.setSlot(0).push(l2Node).follow(); // nodes[node]
            r.read().setOutput(0); // save
        } else {
            return _nullResponse();
        }
        r.debug("before fetch");
        // request it
        fetch(
            verifier,
            r,
            this.resolveCallback.selector,
            abi.encode(name, data), // copy the input
            new string[](0) // use default gateways
        );
    }

    function resolveCallback(
        bytes[] calldata values,
        uint8 exitCode,
        bytes calldata carry
    ) external pure returns (bytes memory) {
        // decode the original request
        (, /*bytes memory name*/ bytes memory data) = abi.decode(
            carry,
            (bytes, bytes)
        );
        // if the request didnt fail internally
        // NOTE: GatewayRequest above doesn't throw any errors
        if (exitCode == 0) {
            if (bytes4(data) == IAddrResolver.addr.selector) {
                return values[0]; // values[0] is already abi.encode(address)
            } else if (bytes4(data) == IAddressResolver.addr.selector) {
                address a = abi.decode(values[0], (address)); // unpack it
                return abi.encode(abi.encodePacked(a)); // repack it
            }
        }
        return _nullResponse();
    }

    function _nullResponse() internal pure returns (bytes memory) {
        //revert("unsupported");

        // NOTE: this abi.decodes for most queries as a null response
        // addr() addr(coinType) text() pubkey() contenthash()
        return new bytes(64);
    }
}
