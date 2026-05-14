// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract Bank{
    // 事件，打印本次转账 地址和存款金额
    event Received(address, uint);
    mapping (address=>uint)public savePrice;
    address internal  owner ;
    address[3] public top3User = [address(0),address(0),address(0)];

// 合约的存款
    // uint counter;

    // constructor(){
        // owner = msg.sender;
    constructor(address initialOwner) {
        owner = initialOwner;
    }

    function getTop3User()public view returns (address[3] memory){
        return top3User;
    }

    function getOwner() view external returns (address){
        return owner;
    }


// 只有管理员可以通过这个方法提取资金
    function withdraw()public {
        require(msg.sender == owner);
        (bool success, ) = payable(owner).call{value:address(this).balance}("");
        require(success, "Withdraw failed");
    }

    

    function saveMoney()payable virtual public  {
        require(msg.value>0, "value must be >0");
        savePrice[msg.sender] += msg.value;
        for (uint8 i = 0;i<3;i++){
            if (top3User[i] == address(0)){
                top3User[i] = msg.sender;
                break;
            }
        }
        // 先判断是否在前三名中
        if (msg.sender == top3User[0] || msg.sender == top3User[1] || msg.sender == top3User[2]){
            // 如果在，则可以直接去排序
        }else {
            // 直接跟第三名比，比第三名大就替代，然后再排序
            if (savePrice[msg.sender] > savePrice[top3User[2]]) {
                top3User[2] = msg.sender;
            }
        }
        // 排序
            if (savePrice[top3User[2]] > savePrice[top3User[1]]) {
                (top3User[2], top3User[1]) = (top3User[1], top3User[2]);
            }
            if (savePrice[top3User[1]] > savePrice[top3User[0]]) {
                (top3User[1], top3User[0]) = (top3User[0], top3User[1]);
            }

    }

    receive() external payable { 
        emit Received(msg.sender, msg.value);
    }

}


// 


