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
interface ResolverABI {
    function addr(
        bytes32 node,
        uint256 coinType
    ) external view returns (bytes memory);
    function text(
        bytes32 node,
        string calldata key
    ) external view returns (string memory);
    function contenthash(bytes32 node) external view returns (bytes memory);
}

uint256 constant EVM_BIT = 0x80000000;
uint256 constant DEFAULT_EVM_COIN_TYPE = EVM_BIT;
uint256 constant OWNER_COIN_TYPE = uint256(keccak256("owner"));

contract L1Resolver is IERC165, IExtendedResolver, GatewayFetchTarget {
    using GatewayFetcher for GatewayRequest;

    IGatewayVerifier public immutable verifier;
    string[] public gateways;
    address public immutable target;

    constructor(address _verifier, string[] memory _gateways, address _target) {
        verifier = IGatewayVerifier(_verifier);
        gateways = _gateways;
        target = _target;
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
        GatewayRequest memory r = GatewayFetcher.newRequest(3);
        r.setTarget(target); // target storage contract
        bytes memory label = name[1:1 + uint8(name[0])]; // extract leading label
        r.setSlot(0).push(keccak256(label)).follow(); // _records[node]
        r.read().requireNonzero(1).setOutput(0); // read owner
        // check if its a request we understand
        if (bytes4(data) == ResolverABI.text.selector) {
            (, string memory key) = abi.decode(data[4:], (bytes32, string));
            r.offset(2).push(key).follow().readBytes().setOutput(1); // texts[key]
        } else if (bytes4(data) == IAddrResolver.addr.selector) {
            r.offset(3).getSlot(); // remember
            r.push(60).follow().readBytes().setOutput(1); // read addrs(60)
            r.slot(); // restore
            r.push(DEFAULT_EVM_COIN_TYPE).follow().readBytes().setOutput(2); // addrs(default)
        } else if (bytes4(data) == ResolverABI.addr.selector) {
            (, uint256 coinType) = abi.decode(data[4:], (bytes32, uint256));
            r.offset(3).getSlot(); // remember
            r.push(coinType).follow().readBytes().setOutput(1); // addrs(coinType)
            if ((coinType & EVM_BIT) != 0) {
                r.slot(); // restore
                r.push(DEFAULT_EVM_COIN_TYPE).follow().readBytes().setOutput(2); // addrs(default)
            }
        } else if (bytes4(data) == ResolverABI.contenthash.selector) {
            r.offset(4).read().requireNonzero(2); // require hash
            r.offset(1).readHashedBytes().setOutput(1);
        } else {
            return _nullResponse();
        }
        //r.debug("before fetch");
        fetch(
            verifier,
            r,
            this.resolveCallback.selector,
            data, // remember the calldata
            gateways
        );
    }

    function resolveCallback(
        bytes[] calldata values,
        uint8 exitCode,
        bytes calldata data
    ) external pure returns (bytes memory) {
        // exitCode = 0 => success
        // exitCode = 1 => no owner
        // exitCode = 2 => no contenthash
        // values[0] = owner
        // values[1] = value
        // values[2] = backup evm if addr(evm)
        if (exitCode == 0) {
            if (bytes4(data) == ResolverABI.text.selector) {
                return abi.encode(values[1]);
            } else if (bytes4(data) == IAddrResolver.addr.selector) {
                bytes memory v = values[1]; // addr(60)
                if (v.length == 0) v = values[2]; // addr(default)
                if (v.length == 20) {
                    return abi.encode(address(bytes20(v)));
                }
            } else if (bytes4(data) == ResolverABI.addr.selector) {
                (, uint256 coinType) = abi.decode(data[4:], (bytes32, uint256));
                bytes memory v = values[1];
                if (coinType == OWNER_COIN_TYPE) {
                    v = abi.encodePacked(abi.decode(values[0], (address)));
                } else if ((coinType & EVM_BIT) != 0 && v.length == 0) {
                    v = values[2]; // use addr(default)
                }
                return abi.encode(v);
            } else if (bytes4(data) == ResolverABI.contenthash.selector) {
                return abi.encode(values[1]);
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
