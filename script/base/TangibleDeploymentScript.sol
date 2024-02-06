// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {DeploymentScriptBase} from "./DeploymentScriptBase.sol";

/**
 * @title Tangible Deployment Script
 * @notice This abstract contract extends DeploymentScriptBase for the Tangible ecosystem, using a specific salt
 * ('tangible.deployment') for CREATE2 address calculations. This salt ensures deterministic address generation
 * for
 * contracts deployed within the Tangible ecosystem.
 * @dev The contract inherits DeploymentScriptBase's functionality, tailoring it to the Tangible ecosystem's deployment
 * needs. It uses the 'tangible.deployment' salt for all CREATE2 address calculations, providing consistency and
 * predictability in contract addresses.
 *
 * Key Features:
 * - Inherits the robust deployment and proxy management system of DeploymentScriptBase.
 * - Uses a specific salt ('tangible.deployment') to ensure deterministic and consistent CREATE2 address generation.
 * - Sets the stage for deploying various components of the Tangible ecosystem with predictable addresses.
 *
 * As an abstract contract, it forms the base for concrete deployment scripts within the Tangible ecosystem, requiring
 * further customization for deploying specific contracts.
 */
abstract contract TangibleDeploymentScript is DeploymentScriptBase {
    constructor() DeploymentScriptBase("tangible.deployment") {}
}
