// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/Script.sol";

import {BytesLib} from "@layerzerolabs/contracts/libraries/BytesLib.sol";

import {DeploymentScriptBase} from "./DeploymentScriptBase.sol";

import {USTB} from "../src/USTB.sol";

// FOUNDRY_PROFILE=optimized forge script ./script/01_ConfigureLayerZero.s.sol --rpc-url $RPC_URL --broadcast
contract DeploymentScript is DeploymentScriptBase {
    using BytesLib for bytes;

    mapping(uint256 => uint16) lzChainIds;

    function run() public broadcast {
        lzChainIds[getChain("mainnet").chainId] = 101;
        lzChainIds[getChain("bnb_smart_chain").chainId] = 102;
        lzChainIds[getChain("polygon").chainId] = 109;
        lzChainIds[getChain("arbitrum_one").chainId] = 110;
        lzChainIds[getChain("optimism").chainId] = 111;
        lzChainIds[getChain("base").chainId] = 184;

        lzChainIds[getChain("goerli").chainId] = 10121;
        lzChainIds[getChain("polygon_mumbai").chainId] = 10109;

        (address ustbAddress,) = _computeProxyAddress("USTB");

        string[2] memory testnets = ["goerli", "polygon_mumbai"];

        for (uint256 i = 0; i < testnets.length; i++) {
            if (getChain(testnets[i]).chainId == block.chainid) {
                for (uint256 j = 0; j < testnets.length; j++) {
                    if (i == j) continue;
                    _updateTrustedRemote(getChain(testnets[j]).chainId, ustbAddress);
                }
            }
        }

        string[1] memory mainnets = ["mainnet"];

        for (uint256 i = 0; i < mainnets.length; i++) {
            if (getChain(mainnets[i]).chainId == block.chainid) {
                for (uint256 j = 0; j < mainnets.length; j++) {
                    if (i == j) continue;
                    _updateTrustedRemote(getChain(mainnets[j]).chainId, ustbAddress);
                }
            }
        }
    }

    function _updateTrustedRemote(uint256 remoteChainId, address ustb) internal {
        bool setTrustedRemoteAddress;
        try USTB(ustb).getTrustedRemoteAddress(lzChainIds[remoteChainId]) returns (bytes memory trustedRemote) {
            setTrustedRemoteAddress = trustedRemote.toAddress(0) != ustb;
        } catch (bytes memory) {
            setTrustedRemoteAddress = true;
        }

        if (setTrustedRemoteAddress) {
            USTB(ustb).setTrustedRemoteAddress(lzChainIds[remoteChainId], abi.encodePacked(ustb));
        }
    }
}