// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BNB is ERC20 {
    constructor(uint256 initialSupply) ERC20("Binance", "BNB") {
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
    function faucet() public {
        _mint(msg.sender, 1000 * 10 ** decimals());
    }
}