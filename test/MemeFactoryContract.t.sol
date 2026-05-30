// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import {Test} from "forge-std/Test.sol";
import {MemeFactoryContract} from "../src/MemeFactoryContract.sol";
import {Meme} from "../src/Meme.sol";


contract MemeFactoryContractTest is Test {
    MemeFactoryContract public memeFactoryContract;
    Meme public memeToken;
    address public projectOwner;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address seller = makeAddr("seller");
    address seller2 = makeAddr("seller2");
    address buyer = makeAddr("buyer");
    address buyer2 = makeAddr("buyer2");

    function setUp() public {
        vm.startPrank(user1);
        memeFactoryContract = new MemeFactoryContract();
        projectOwner = memeFactoryContract.projectOwner();

        vm.stopPrank();
        vm.deal(user1, 10000 ether);
        vm.deal(user2, 10000 ether);
        vm.deal(seller, 10000 ether);
        vm.deal(seller2, 10000 ether);
        vm.deal(buyer, 10000 ether);
        vm.deal(buyer2, 10000 ether);
    }

// 测试部署meme合约
// 1、验证meme合约是否部署成功，参数是否初始化成功。非工厂addr调用mint，是否触发revert
// 2、测试一次铸造的数量是否正确
// 3、测试铸造后余额是否正确
// 4、测试铸造数量上限是否触发revert
// 5、测试费用比例是否准确，项目方1%，剩余的99%给发行者
// 6、测试如果少付了eth，是否触发revert，用户多付了ETH，是否退还正确
// 7、传入非工厂创建的tokenAddr，是否触发revert
    function test_deployMeme() public {
        vm.startPrank(user2);
        // 非工厂addr调用mint，是否触发revert
        memeToken = new Meme();

        vm.expectRevert("Meme: only factory can mint");
        memeToken.mint(user2);

//    验证meme合约是否部署成功，参数是否初始化成功
        address tokenAddr = memeFactoryContract.deployMeme("Meme", "Meme", 1000e18, 100e18, 1 ether);
        assertEq("Meme", (Meme(tokenAddr).name()));
        assertEq("Meme", (Meme(tokenAddr).symbol()));
        assertEq(1000e18, (Meme(tokenAddr).totalSupplyLimit()));
        assertEq(100e18, (Meme(tokenAddr).perMintAmount()));
        assertEq(1 ether, (Meme(tokenAddr).mintPrice()));
        assertEq(user2, (Meme(tokenAddr).issuer()));
        assertEq(address(memeFactoryContract), (Meme(tokenAddr).factory()));
        vm.stopPrank();

// 2、测试一次铸造的数量是否正确，3、余额是否正确
        vm.startPrank(buyer);
        uint256 buyerBeforeBalance = buyer.balance;
        uint256 user1BeforeBalance = user1.balance;
        uint256 user2BeforeBalance = user2.balance;
        uint256 totalCost = 1 ether * 100e18 / 1e18; 
        uint256 projectFee = totalCost / 100;           // 1%
        uint256 issuerFee  = totalCost - projectFee;    // 99%
        memeFactoryContract.mintMeme{value: 100 ether}(tokenAddr);
        assertEq(100e18, Meme(tokenAddr).balanceOf(buyer));
        assertEq(100e18, Meme(tokenAddr).totalSupply());

// 5、测试费用比例是否准确，项目方1%，剩余的99%给发行者
        assertEq(user1.balance, user1BeforeBalance + projectFee);
        assertEq(user2.balance, user2BeforeBalance + issuerFee);

// 6、测试如果少付了eth，是否触发revert，用户多付了ETH，是否退还正确
        uint256 buyerBeforeBalance2 = buyer.balance;
        vm.expectRevert("Insufficient funds");
        memeFactoryContract.mintMeme{value: 99 ether}(tokenAddr);
        assertEq(buyer.balance, buyerBeforeBalance2);

//   多付了1 ether 
        memeFactoryContract.mintMeme{value: 101 ether}(tokenAddr);
        assertEq(buyer.balance, buyerBeforeBalance2 -100 ether);


// 7、传入非工厂创建的tokenAddr，是否触发revert
        vm.expectRevert("Token is not deployed by this factory");
        memeFactoryContract.mintMeme{value: 1 ether}(address(0x12));

// 4、测试铸造数量上限是否触发revert.到目前为止，总共成功铸造了2次
        memeFactoryContract.mintMeme{value: 100 ether}(tokenAddr);
        memeFactoryContract.mintMeme{value: 100 ether}(tokenAddr);
        memeFactoryContract.mintMeme{value: 100 ether}(tokenAddr);
        memeFactoryContract.mintMeme{value: 100 ether}(tokenAddr);
        memeFactoryContract.mintMeme{value: 100 ether}(tokenAddr);
        memeFactoryContract.mintMeme{value: 100 ether}(tokenAddr);
        memeFactoryContract.mintMeme{value: 100 ether}(tokenAddr);
        memeFactoryContract.mintMeme{value: 100 ether}(tokenAddr);

// 到这里，已经到达了铸造上限
        vm.expectRevert("Meme: total supply limit reached");
        memeFactoryContract.mintMeme{value: 100 ether}(tokenAddr);


    }





}










