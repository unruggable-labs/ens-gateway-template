# ens-gateway-template

1. `foundryup`
1. `bun i`
1. `bun test/testnet.ts` &mdash; uses [`sepolia:0x83FC`](https://sepolia.etherscan.io/address/0x83fc17a94115ae805f7c251635363eed5180fdae)
1. `bun test/local.ts` &mdash; local testnet

### General Setup

1. [`bun i @unruggable/gateways`](https://www.npmjs.com/package/@unruggable/gateways)
1. create [`foundry.toml`](./foundry.toml)
1. add remapping for `@unruggable`
```toml
[profile.default]
#lib = ["lib", "node_modules"] # NOTE: this is the forge default
remappings = [
    '@unruggable/=node_modules/@unruggable/'
]
```
4. import the request builder:
```solidity
import {GatewayFetcher, GatewayRequest} from "@unruggable/gateways/contracts/GatewayFetcher.sol";
import {GatewayFetchTarget, IGatewayVerifier} from "@unruggable/gateways/contracts/GatewayFetchTarget.sol";
```
5. attach `GatewayFetcher` to `GatewayRequest`
```solidity
using GatewayFetcher for GatewayRequest;
```
6. build a request and fetch it
```solidity
function abc(string memory input) external view returns ($RETURN_ARGUMENTS) {
	GatewayRequest memory req = GatewayFetcher.newRequest(1);
	req.setTarget(0x...);
	req.setSlot(123);
	req.readBytes();
	req.setOutput(0);
	fetch(verifier, req, this.abcCallback.selector);

	// you should probably pass the inputs along with the callback
	// you can also supply your own gateways(s), or send empty array to use default
	fetch(verifier, req, this.abcCallback.selector, abi.encode(input), new string[](0));
}
```
> ⚠️ `$RETURN_ARGUMENTS` can be anything but **MUST** match

7. receive callback and return results
```solidity
function abcCallback(bytes[] calldata values, uint8 exitCode, bytes calldata data) external view returns ($RETURN_ARGUMENTS) {
	// if you used req.assert(), req.requireContract(), req.requireNonzero()
	// check if exitCode is nonzero

	// if you passed along extra information, decode it from data
	string memory input = abi.decode(data, (string));

	// parse values and return result
	return (...);
}
```
