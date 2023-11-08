// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IUSTB is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;

    function disableRebase(address account, bool disable) external;

    function setRebaseIndex(uint256 index, uint256 nonce) external;
    function setRebaseIndexManager(address manager) external;

    function rebaseIndexManager() external returns (address manager);
}
