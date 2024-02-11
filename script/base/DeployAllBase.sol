// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console} from "forge-std/Script.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {TangibleDeploymentScript} from "./TangibleDeploymentScript.sol";

import {USTB} from "../../src/USTB.sol";

abstract contract DeployAllBase is TangibleDeploymentScript {
    function run() public {
        _setup();

        string memory mainChainAlias = _getMainChainAlias();
        string[] memory deploymentChainAliases = _getDeploymentChainAliases();

        uint256 mainChainId = getChain(mainChainAlias).chainId;
        address usdmAddress = _getUSDMAddress();

        for (uint256 i = 0; i < deploymentChainAliases.length; i++) {
            console.log("---");
            vm.createSelectFork(deploymentChainAliases[i]);
            vm.startBroadcast(_pk);
            address ustbAddress = _deployUSTB(mainChainId, usdmAddress);
            USTB ustb = USTB(ustbAddress);
            for (uint256 j = 0; j < deploymentChainAliases.length; j++) {
                if (i != j) {
                    if (
                        !ustb.isTrustedRemote(
                            _getLzChainId(deploymentChainAliases[j]), abi.encodePacked(ustbAddress, ustbAddress)
                        )
                    ) {
                        ustb.setTrustedRemoteAddress(
                            _getLzChainId(deploymentChainAliases[j]), abi.encodePacked(ustbAddress)
                        );
                    }
                }
            }
            vm.stopBroadcast();
        }
    }

    function _getUSDMAddress() internal pure virtual returns (address);

    /**
     * @dev Virtual function to be overridden in derived contracts to return the alias of the main chain in the Pearl
     * ecosystem deployment. This alias is crucial for identifying the primary network where specific operations like
     * preminting will occur.
     *
     * Implementations in derived contracts should specify the chain alias that represents the main network in the
     * context of the Pearl ecosystem.
     *
     * @return A string representing the alias of the main chain.
     */
    function _getMainChainAlias() internal pure virtual returns (string memory);

    /**
     * @dev Virtual function to be overridden in derived contracts to provide an array of chain aliases where the USTB
     * token will be deployed. This list is essential for ensuring the deployment and configuration of USTB across
     * multiple networks.
     *
     * Implementations in derived contracts should return an array of strings, each representing a chain alias for
     * deploying the USTB token.
     *
     * @return aliases An array of strings representing the aliases of chains for deployment.
     */
    function _getDeploymentChainAliases() internal pure virtual returns (string[] memory aliases);

    function _deployUSTB(uint256 mainChainId, address usdmAddress) private returns (address ustbProxy) {
        address lzEndpoint = _getLzEndpoint();
        bytes memory bytecode = abi.encodePacked(type(USTB).creationCode);

        address ustbAddress = vm.computeCreate2Address(
            _SALT, keccak256(abi.encodePacked(bytecode, abi.encode(usdmAddress, mainChainId, lzEndpoint)))
        );

        USTB ustb;

        if (_isDeployed(ustbAddress)) {
            console.log("USTB is already deployed to %s", ustbAddress);
            ustb = USTB(ustbAddress);
        } else {
            ustb = new USTB{salt: _SALT}(usdmAddress, mainChainId, lzEndpoint);
            assert(ustbAddress == address(ustb));
            console.log("USTB deployed to %s", ustbAddress);
        }

        bytes memory init = abi.encodeWithSelector(
            USTB.initialize.selector,
            _deployer // initial index manager
        );

        ustbProxy = _deployProxy("USTB", address(ustb), init);
    }

    /**
     * @dev Retrieves the LayerZero chain ID for a given chain alias. This function is essential for setting up
     * cross-chain communication parameters in the deployment process.
     *
     * The function maps common chain aliases to their respective LayerZero chain IDs. This mapping is crucial for
     * identifying the correct LayerZero endpoint for each chain involved in the deployment.
     *
     * @param chainAlias The alias of the chain for which the LayerZero chain ID is required.
     * @return The LayerZero chain ID corresponding to the given chain alias.
     * Reverts with 'Unsupported chain' if the alias does not match any known chains.
     */
    function _getLzChainId(string memory chainAlias) internal pure returns (uint16) {
        bytes32 chain = keccak256(abi.encodePacked(chainAlias));
        if (chain == keccak256("mainnet")) {
            return 101;
        } else if (chain == keccak256("bnb_smart_chain")) {
            return 102;
        } else if (chain == keccak256("polygon")) {
            return 109;
        } else if (chain == keccak256("arbitrum_one")) {
            return 110;
        } else if (chain == keccak256("optimism")) {
            return 111;
        } else if (chain == keccak256("base")) {
            return 184;
        } else if (chain == keccak256("real")) {
            revert("Unsupported chain");
        } else if (chain == keccak256("goerli")) {
            return 10121;
        } else if (chain == keccak256("sepolia")) {
            return 10161;
        } else if (chain == keccak256("polygon_mumbai")) {
            return 10109;
        } else if (chain == keccak256("unreal")) {
            return 10252;
        } else {
            revert("Unsupported chain");
        }
    }

    function _getLzEndpoint() internal returns (address lzEndpoint) {
        lzEndpoint = _getLzEndpoint(block.chainid);
    }

    /**
     * @dev Overloaded version of `_getLzEndpoint` that retrieves the LayerZero endpoint address for a specified chain
     * ID. This variation allows for more flexibility in targeting specific chains during the deployment process.
     *
     * @param chainId The chain ID for which the LayerZero endpoint address is required.
     * @return lzEndpoint The LayerZero endpoint address for the specified chain ID. Reverts with an error if the chain
     * ID does not have a defined endpoint.
     */
    function _getLzEndpoint(uint256 chainId) internal returns (address lzEndpoint) {
        if (chainId == getChain("mainnet").chainId) {
            lzEndpoint = 0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675;
        } else if (chainId == getChain("bnb_smart_chain").chainId) {
            lzEndpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;
        } else if (chainId == getChain("polygon").chainId) {
            lzEndpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;
        } else if (chainId == getChain("arbitrum_one").chainId) {
            lzEndpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;
        } else if (chainId == getChain("optimism").chainId) {
            lzEndpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;
        } else if (chainId == getChain("base").chainId) {
            lzEndpoint = 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7;
        } else if (chainId == getChain("real").chainId) {
            revert("No LayerZero endpoint defined for this chain.");
        } else if (chainId == getChain("goerli").chainId) {
            lzEndpoint = 0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23;
        } else if (chainId == getChain("sepolia").chainId) {
            lzEndpoint = 0xae92d5aD7583AD66E49A0c67BAd18F6ba52dDDc1;
        } else if (chainId == getChain("polygon_mumbai").chainId) {
            lzEndpoint = 0xf69186dfBa60DdB133E91E9A4B5673624293d8F8;
        } else if (chainId == getChain("unreal").chainId) {
            lzEndpoint = 0x2cA20802fd1Fd9649bA8Aa7E50F0C82b479f35fe;
        } else {
            revert("No LayerZero endpoint defined for this chain.");
        }
    }
}
