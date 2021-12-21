// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BNB is ERC20 {
    constructor(uint256 initialSupply) ERC20("Binance", "BNB") {
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }
    function awardToken(uint256 amount) public {
        _mint(msg.sender, amount * 10 ** decimals());
    }
}