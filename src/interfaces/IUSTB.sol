// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUSTB {
    function UNDERLYING() external view returns (address);

    function burn(address from, uint256 amount) external;
    function mint(address to, uint256 amount) external;

    function rebaseIndexManager() external view returns (address _rebaseIndexManager);

    function refreshRebaseIndex() external;

    function setRebaseIndexManager(address manager) external;
}
