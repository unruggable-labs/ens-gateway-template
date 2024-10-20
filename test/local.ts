import { Foundry } from "@adraffy/blocksmith";
import { serve } from "@resolverworks/ezccip/serve";
import { EthSelfRollup, Gateway } from "@unruggable/gateways";
import { EnsResolver } from "ethers";

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
const L2DataStorage = await foundry.deploy({ file: "L2DataContract.sol" });

// create some names
await foundry.confirm(
	L2DataStorage.register(
		"raffy",
		"0x51050ec063d393217B436747617aD1C2285Aeeee"
	)
);
await foundry.confirm(
	L2DataStorage.register("a", "0xaAaAaAaaAaAaAaaAaAAAAAAAAaaaAaAaAaaAaaAa")
);

// deploy L1 contract
const L1SimpleResolver = await foundry.deploy({
	file: "L1SimpleResolver",
	args: [SelfVerifier, L2DataStorage],
});

// query a name
async function resolve(name: string) {
	const resolver = new EnsResolver(
		foundry.provider,
		L1SimpleResolver.target,
		`${name}.jacobhomanics-test.eth`
	);
	const address = await resolver.getAddress();
	return { name, address };
}

console.log(await resolve("raffy"));
console.log(await resolve("a"));

await ccip.shutdown();
await foundry.shutdown();
