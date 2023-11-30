// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {DeployAllBase} from "./base/DeployAllBase.sol";

// FOUNDRY_PROFILE=optimized forge script ./script/DeployAllTestnet.s.sol --broadcast
contract DeployAll is DeployAllBase {
    function _getUSDMAddress() internal pure override returns (address) {
        return 0xe31Cf614fC1C5d3781d9E09bdb2e04134CDebb89;
    }

    function _getMainChainAlias() internal pure override returns (string memory) {
        return "goerli";
    }

    function _getDeploymentChainAliases() internal pure override returns (string[] memory aliases) {
        aliases = new string[](3);
        aliases[0] = "goerli";
        aliases[1] = "polygon_mumbai";
        aliases[2] = "unreal";
    }
}
