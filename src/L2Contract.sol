//SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

uint256 constant DEFAULT_EVM_COIN_TYPE = 0x80000000;

contract L2Contract {
    event Registered(bytes32 indexed token, string name);
    event Changed(bytes32 indexed token);

    struct Hashed {
        bytes32 hash;
        bytes value;
    }

    function _makeHashed(bytes memory v) internal pure returns (Hashed memory) {
        return Hashed(keccak256(v), v);
    }

    struct Record {
        address owner;
        string name;
        mapping(string key => string) texts;
        mapping(uint256 coinType => bytes) addrs;
        Hashed contenthash;
    }

    mapping(bytes32 => Record) _records;

    function register(string calldata name) external {
        bytes32 token = keccak256(bytes(name));
        Record storage r = _records[token];
        require(r.owner == address(0), "owned");
        r.owner = msg.sender;
        r.name = name;
        r.addrs[DEFAULT_EVM_COIN_TYPE] = abi.encodePacked(msg.sender);
        emit Registered(token, name);
    }

    struct TextValue {
        string key;
        string value;
    }
    struct AddrValue {
        uint256 coinType;
        bytes value;
    }

    function getRecords(
        bytes32 token,
        string[] memory keys,
        uint256[] memory coinTypes
    )
        external
        view
        returns (
            string memory name,
            address owner,
            string[] memory texts,
            bytes[] memory addrs,
            bytes memory contenthash
        )
    {
        Record storage r = _records[token];
        if (r.owner != address(0)) {
            name = r.name;
            owner = r.owner;
            texts = new string[](keys.length);
            for (uint256 i; i < keys.length; i++) {
                texts[i] = r.texts[keys[i]];
            }
            addrs = new bytes[](coinTypes.length);
            for (uint256 i; i < coinTypes.length; i++) {
                addrs[i] = r.addrs[coinTypes[i]];
            }
            contenthash = r.contenthash.value;
        }
    }

    function setRecords(
        bytes32 token,
        TextValue[] memory texts,
        AddrValue[] memory addrs,
        bytes[] memory contenthash
    ) external {
        Record storage r = _records[token];
        require(r.owner == msg.sender, "not owner");
        bool dirty;
        for (uint256 i; i < texts.length; i++) {
            r.texts[texts[i].key] = texts[i].value;
            dirty = true;
        }
        for (uint256 i; i < addrs.length; i++) {
            r.addrs[addrs[i].coinType] = addrs[i].value;
            dirty = true;
        }
        if (contenthash.length == 1) {
            r.contenthash = _makeHashed(contenthash[0]);
            dirty = true;
        }
        require(dirty, "unchanged");
        emit Changed(token);
    }

	// (optional)
    function readBytesAt(uint256 slot) external pure returns (bytes memory) {
        bytes storage v;
        assembly {
            v.slot := slot
        }
        return v;
    }
}
