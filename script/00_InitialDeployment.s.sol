// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/Script.sol";

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {DeploymentScriptBase} from "./DeploymentScriptBase.sol";

import {USTB} from "../src/USTB.sol";

// FOUNDRY_PROFILE=optimized forge script ./script/00_InitialDeployment.s.sol --rpc-url $RPC_URL --broadcast --verify
contract DeploymentScript is DeploymentScriptBase {
    function run() public broadcast {
        address lzEndpoint;

        address underlying = 0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C;
        uint256 mainChainId = getChain("mainnet").chainId;
        bool isTestnet;

        if (block.chainid == getChain("mainnet").chainId) {
            lzEndpoint = 0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675;
        } else if (block.chainid == getChain("bnb_smart_chain").chainId) {
            lzEndpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;
        } else if (block.chainid == getChain("polygon").chainId) {
            lzEndpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;
        } else if (block.chainid == getChain("arbitrum_one").chainId) {
            lzEndpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;
        } else if (block.chainid == getChain("optimism").chainId) {
            lzEndpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;
        } else if (block.chainid == getChain("base").chainId) {
            lzEndpoint = 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7;
        } else {
            isTestnet = true;
            mainChainId = getChain("goerli").chainId;
            underlying = 0xe31Cf614fC1C5d3781d9E09bdb2e04134CDebb89;
            if (block.chainid == getChain("goerli").chainId) {
                lzEndpoint = 0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23;
            } else if (block.chainid == getChain("polygon_mumbai").chainId) {
                lzEndpoint = 0xf69186dfBa60DdB133E91E9A4B5673624293d8F8;
            } else {
                revert("No LayerZero endpoint defined for this chain.");
            }
        }

        bytes memory bytecode = abi.encodePacked(type(USTB).creationCode);

        address ustbAddress = computeCreate2Address(
            _SALT, keccak256(abi.encodePacked(bytecode, abi.encode(underlying, mainChainId, lzEndpoint)))
        );

        USTB ustb;

        if (_isDeployed(ustbAddress)) {
            console.log("USTB is already deployed to %s", ustbAddress);
            ustb = USTB(ustbAddress);
        } else {
            ustb = new USTB{salt: _SALT}(underlying, mainChainId, lzEndpoint);
            assert(ustbAddress == address(ustb));
            console.log("USTB deployed to %s", ustbAddress);
        }

        bytes memory init = abi.encodeWithSelector(
            USTB.initialize.selector,
            _deployer // initial index manager
        );

        _deployProxy("USTB", address(ustb), init);
    }
}
