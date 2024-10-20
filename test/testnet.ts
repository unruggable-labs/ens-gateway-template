import { Foundry } from "@adraffy/blocksmith";
import { EnsResolver } from "ethers";

const foundry = await Foundry.launch({
	fork: "https://rpc.ankr.com/eth_sepolia",
	infoLog: false,
});

// self-sepolia verifier
// https://gateway-docs.unruggable.com/verifier-deployments#current-sepolia-deployments
const UnruggableGateway = "0xBAb69B0B5241c0be99282d531b9c53d7c966864F";

// https://sepolia.etherscan.io/address/0x83fc17a94115ae805f7c251635363eed5180fdae
const L2DataStorage = "0x83FC17A94115aE805f7C251635363eED5180FdAe";

const L1SimpleResolver = await foundry.deploy({
	file: "L1SimpleResolver",
	args: [UnruggableGateway, L2DataStorage],
});

async function resolve(name: string) {
	const resolver = new EnsResolver(
		foundry.provider,
		L1SimpleResolver.target,
		`${name}.jacobhomanics-test.eth`
	);
	const address = await resolver.getAddress();
	return { name, address };
}

// https://sepolia.etherscan.io/tx/0xcc977695101691c70ece48526940467a45581c255bf0cde4e4a5fa2d51e37319
console.log(await resolve("test"));

await foundry.shutdown();
