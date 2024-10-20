import { Foundry } from "@adraffy/blocksmith";
import { resolve } from "./resolve.js";

const foundry = await Foundry.launch({
	fork: "https://rpc.ankr.com/eth_sepolia",
});

// self-sepolia verifier
// https://gateway-docs.unruggable.com/verifier-deployments#current-sepolia-deployments
const UnruggableGateway = "0xBAb69B0B5241c0be99282d531b9c53d7c966864F";

const L2Contract = "0x"; // address of your deployment on sepolia

const L1Resolver = await foundry.deploy({
	file: "L1Resolver",
	args: [UnruggableGateway, L2Contract],
});

console.log(await resolve(L1Resolver, "test")); // some name you registered

await foundry.shutdown();
