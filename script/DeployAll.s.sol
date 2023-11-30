// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {DeployAllBase} from "./base/DeployAllBase.sol";

// FOUNDRY_PROFILE=optimized forge script ./script/DeployAll.s.sol --broadcast
contract DeployAll is DeployAllBase {
    function _getUSDMAddress() internal pure override returns (address) {
        return 0x59D9356E565Ab3A36dD77763Fc0d87fEaf85508C;
    }

    function _getMainChainAlias() internal pure override returns (string memory) {
        return "mainnet";
    }

    function _getDeploymentChainAliases() internal pure override returns (string[] memory aliases) {
        aliases = new string[](7);
        aliases[0] = "mainnet";
        aliases[1] = "bnb_smart_chain";
        aliases[2] = "polygon";
        aliases[3] = "arbitrum_one";
        aliases[4] = "optimism";
        aliases[5] = "base";
        aliases[6] = "real";
    }
}
