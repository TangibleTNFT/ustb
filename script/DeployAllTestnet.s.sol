// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {DeployAllBase} from "./base/DeployAllBase.sol";

// FOUNDRY_PROFILE=optimized forge script ./script/DeployAllTestnet.s.sol --broadcast
contract DeployAll is DeployAllBase {
    function _getUSDMAddress() internal pure override returns (address) {
        return 0x13613fb95931D7cC2F1ae3E30e5090220f818032;
    }

    function _getMainChainAlias() internal pure override returns (string memory) {
        return "sepolia";
    }

    function _getDeploymentChainAliases() internal pure override returns (string[] memory aliases) {
        aliases = new string[](4);
        aliases[0] = "unreal";
        aliases[1] = "polygon_mumbai";
        aliases[2] = "sepolia";
        aliases[3] = "arbitrum_one_sepolia";
    }
}
