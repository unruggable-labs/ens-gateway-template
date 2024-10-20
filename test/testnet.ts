import { Foundry } from "@adraffy/blocksmith";
import { resolve } from "./resolve.js";

// address of your deployment on "L2" eg. sepolia
const L2Contract = "0x952447FBb1380D740aE5e63fc8eB397BBF30CE0e";

// self verifier for testing on same chain (L1 = L2)
// https://gateway-docs.unruggable.com/verifier-deployments
const UnruggableGateway = "0xBAb69B0B5241c0be99282d531b9c53d7c966864F";

const foundry = await Foundry.launch({
	fork: "https://rpc.ankr.com/eth_sepolia", // rpc for "L1" eg. sepolia
});

// deploy L1Resolver on fork of "L1"
const L1Resolver = await foundry.deploy({
	file: "L1Resolver",
	args: [UnruggableGateway, [], L2Contract],
});

// resolve a name
console.log(await resolve(L1Resolver, "raffy.any.domain.works")); // a name you registered

await foundry.shutdown();
