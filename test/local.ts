import { Foundry } from "@adraffy/blocksmith";
import { serve } from "@resolverworks/ezccip/serve";
import { EthSelfRollup, Gateway } from "@unruggable/gateways";
import { id, randomBytes } from "ethers";
import { EVM_BIT, resolve } from "./resolve.js";

const foundry = await Foundry.launch();

// setup gateway
const gateway = new Gateway(new EthSelfRollup(foundry.provider));
gateway.rollup.latestBlockTag = "latest";
const ccip = await serve(gateway, {
	protocol: "raw",
});

// deploy local verifier
function getArtifactPath(name: string) {
	return `node_modules/@unruggable/gateways/artifacts/${name}.sol/${name}.json`;
}
const GatewayVM = await foundry.deploy({ file: getArtifactPath("GatewayVM") });
const EthVerifierHooks = await foundry.deploy({
	file: getArtifactPath("EthVerifierHooks"),
});
const SelfVerifier = await foundry.deploy({
	file: getArtifactPath("SelfVerifier"),
	args: [[ccip.endpoint], 1000, EthVerifierHooks],
	libs: { GatewayVM },
});

// deploy L2 contract
const L2Contract = await foundry.deploy({ file: "L2Contract" });

// create some names
await foundry.confirm(L2Contract.register("raffy"));
await foundry.confirm(
	L2Contract.setRecords(
		id("raffy"),
		[["chonk", "CHONK"]],
		[[60, "0x51050ec063d393217B436747617aD1C2285Aeeee"]],
		["0x1234"]
	)
);

const person = await foundry.ensureWallet("person");
await foundry.confirm(L2Contract.connect(person).register("person"));
await foundry.confirm(
	L2Contract.connect(person).setRecords(
		id("person"),
		[['url', 'chonk.com']],
		[],
		[randomBytes(343)] // store a bunch of data
	)
);

// deploy L1 contract
const L1Resolver = await foundry.deploy({
	file: "L1Resolver",
	args: [SelfVerifier, [], L2Contract],
});

// query the names
console.log(
	await resolve(L1Resolver, "raffy.chonk", {
		coins: [60, EVM_BIT | 8453n],
		keys: ["chonk"],
	})
);
console.log(
	await resolve(L1Resolver, "person.any.domain.works", {
		keys: ['url'],
		coins: [EVM_BIT | 8453n],
	})
);

await ccip.shutdown();
await foundry.shutdown();
