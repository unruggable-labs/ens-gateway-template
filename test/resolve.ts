import { Resolver } from "@adraffy/blocksmith";
import {
	Contract,
	dnsEncode,
	id,
	namehash,
	Result,
	type BigNumberish,
} from "ethers";

export const EVM_BIT = 0x80000000n;
export const DEFAULT_EVM_COIN_TYPE = EVM_BIT;
export const OWNER_COIN_TYPE = BigInt(id("owner"));

export async function resolve(
	L1Resolver: Contract,
	name: string,
	{ keys = [], coins = [] }: { keys?: string[]; coins?: BigNumberish[] } = {}
) {
	const node = namehash(name);
	const dnsname = dnsEncode(name, 255);
	const texts: Record<string, Result> = {};
	const addrs: Record<string, Result> = {};
	// call the old style
	const addr = await callExtendedResolver("addr(bytes32)");
	// get texts
	for (const key of keys) {
		texts[key] = await callExtendedResolver("text", key);
	}
	// get addresses
	for (const x of [...coins, DEFAULT_EVM_COIN_TYPE, OWNER_COIN_TYPE]) {
		const coinType = BigInt(x);
		addrs[formatCoinType(coinType)] = await callExtendedResolver(
			"addr(bytes32,uint256)",
			coinType
		);
	}
	// get contenthash
	const contenthash = await callExtendedResolver("contenthash");
	return { name, texts, addr, addrs, contenthash };
	async function callExtendedResolver(frag: string, ...a: any[]) {
		const resolved = await L1Resolver.resolve(
			dnsname,
			Resolver.ABI.encodeFunctionData(frag, [node, ...a]),
			{ enableCcipRead: true }
		);
		const result = Resolver.ABI.decodeFunctionResult(frag, resolved);
		return result.length == 1 ? result[0] : result.toObject();
	}
}

function formatCoinType(x: bigint) {
	if (x === OWNER_COIN_TYPE) {
		return "owner";
	} else if (x === DEFAULT_EVM_COIN_TYPE) {
		return "evm:default";
	} else if (x === 60n) {
		return "evm:1";
	} else if (x & EVM_BIT) {
		return `evm:${BigInt.asUintN(31, x)}`;
	} else {
		return x.toString();
	}
}
