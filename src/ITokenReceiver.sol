// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokenReceiver {
    function tokensReceived(address from,uint value)external returns (bool);
}