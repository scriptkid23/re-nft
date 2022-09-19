// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
/*
FOR TEST ONLY
*/
contract TokenTest is ERC20 {
    constructor() ERC20("Gold", "GLD") {
        _mint(msg.sender, 100000 * 10**uint256(18));
    }
}