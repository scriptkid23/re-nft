// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IWETH {
    function deposit() external payable;
    function withdraw(uint) external;
    function transfer(address to, uint value) external returns (bool);
}
