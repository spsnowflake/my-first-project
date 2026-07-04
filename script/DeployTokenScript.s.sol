// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import {Script} from "../lib/forge-std/src/Script.sol";
// import {FlashSwap} from "../src/FlashSwap.sol";

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MyToken} from "../src/MyToken.sol";
import {console2} from "../lib/forge-std/src/console2.sol";


contract DeployTokenScript is Script {
    MyToken public token1;
    MyToken public token2;

    address public owner;

    function setUp() public {

    }
    
    function run() public {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        owner = vm.addr(deployerPrivateKey);

// 创建token1和token2
        vm.startBroadcast(deployerPrivateKey);

        token1 = new MyToken("MyToken1", "MyToken1");
        token2 = new MyToken("MyToken2", "MyToken2");

        vm.stopBroadcast();

        console2.log("MyToken1", address(token1));
        console2.log("MyToken2", address(token2));
    }
       
}














