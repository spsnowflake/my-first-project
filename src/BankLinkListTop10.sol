// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract BankLinkListTop10{
    // 事件，打印本次转账 地址和存款金额
    event Received(address, uint);
    mapping (address=>uint)public addressToSavePrice;
    mapping (address=>address)public top10Address;
    address internal owner;
    uint8 public listSize;
    address public constant GUARD = address(1);

    constructor(){
        owner = msg.sender;
        top10Address[GUARD] = GUARD;
        listSize = 0;
    }

// 只有管理员可以通过这个方法提取资金
    function withdraw()public {
        require(msg.sender == owner);
        (bool success, ) = payable(owner).call{value:address(this).balance}("");
        require(success, "Withdraw failed");
    }

// 判断用户地址是否在top10中。在则返回true，不在则返回false
    function isUserInTop10(address userAddress) internal view returns (bool) {
        return top10Address[userAddress] != address(0);
    }

// 获取下一个节点地址
    function nextAddress(address _Address) internal view returns (address) {
        return top10Address[_Address];
    }

    // 循环比较，获取top10中金额刚好大于用户地址的节点.找到用户地址金额小于下个地址金额的节点，并返回该节点
    function getGreaterThanUserAddress(address userAddress,address currentAddress) internal view returns (address,address) {
        address _currentAddress = currentAddress;
        address next_Address = nextAddress(_currentAddress);
        while(next_Address != GUARD){
            if ( addressToSavePrice[userAddress]<=addressToSavePrice[next_Address] ) {
                return (_currentAddress,next_Address);
            }
            _currentAddress = next_Address;
            next_Address = nextAddress(_currentAddress);
        }
        return (_currentAddress,next_Address);
    }

// 获取用户地址的前一个节点。前提排除头节点。
    function preAddress(address userAddress) internal view returns (address) {
        // address _preAddress = address(0);
        address _currentAddress = top10Address[GUARD];
        while(_currentAddress != GUARD){
            if(nextAddress(_currentAddress) == userAddress){
                return _currentAddress;
            }
            _currentAddress = nextAddress(_currentAddress);
        }
        return address(0);
    }

    // 添加到top10中
    function addToTop10(address userAddress) internal {
       // 如果用户地址不在top10中，则需要添加到top10中
        if(!isUserInTop10(userAddress)){
            // 如果头节点是GUARD，则说明top10为空，则直接将用户地址添加到头节点
            if(top10Address[GUARD] == GUARD){
                top10Address[userAddress] = GUARD;
                top10Address[GUARD] = userAddress;
                listSize++;
            }else{
                // 如果头节点不是GUARD，则说明top10不为空，则需要将用户地址添加到top10中。
                // 先跟头结点比，头结点是存款最少的，比不过头结点则判断listsize是否等于9，如果等于9则说明top10已满，满则不添加。
                //  如果小于9则直接插入头结点，且更新listsize。如果比头结点大，则继续跟下一个节点比，直到找到合适的位置
                if (listSize <10 && addressToSavePrice[userAddress] < addressToSavePrice[top10Address[GUARD]]) {
                    top10Address[userAddress] = top10Address[GUARD];
                    top10Address[GUARD] = userAddress;
                    listSize++;
                }else if (listSize <10 && addressToSavePrice[userAddress] >= addressToSavePrice[top10Address[GUARD]]) {
                    // 获取用户地址金额刚好大于用户地址的节点
                    (address _preAddress,address _nextAddress) = getGreaterThanUserAddress(userAddress,top10Address[GUARD]);
                    // 将用户地址插入到下个地址之前
                    top10Address[_preAddress] = userAddress;
                    top10Address[userAddress] = _nextAddress;
                    listSize++;

                    // 如果top10满了，先跟最小的存款比较， 比最小的存款大，则需要将用户地址插入到top10中，且删除最小的地址
                }else if (listSize == 10 && addressToSavePrice[userAddress] > addressToSavePrice[top10Address[GUARD]]){
                    // 先获取第二小的存款地址
                    address secondSmallestAddress = top10Address[top10Address[GUARD]];
                    address smallestAddress = top10Address[GUARD];
                    top10Address[smallestAddress] = address(0);
                    // 先给头节点赋值为第二小的存款地址
                    top10Address[GUARD] = secondSmallestAddress;
                    // 如果用户地址的存款比第二小的存款小或等于，则将用户地址插入到最后
                    if(addressToSavePrice[userAddress] <= addressToSavePrice[secondSmallestAddress]){
                        top10Address[userAddress] = secondSmallestAddress;
                        top10Address[GUARD] = userAddress;

                        // 如果用户地址的存款比第二小的存款大，则继续跟下一个节点比，直到找到合适的位置
                    }else{
                        (address _preAddress,address _nextAddress) = getGreaterThanUserAddress(userAddress,secondSmallestAddress);
                        top10Address[_preAddress] = userAddress;
                        top10Address[userAddress] = _nextAddress;
                    }
                }
            }
        }
    }

     // 用户在前10中，更新用户的排名
    function updateTop10(address userAddress) internal {
    // 如果只有1人，不需要比较。大于1个，则需要比较。
        if(listSize >1){
            // 先删除，然后添加
            removeFromTop10(userAddress);
            addToTop10(userAddress);
        }
    }
    

// 删除用户地址
    function removeFromTop10(address userAddress) internal {
        // 如果用户地址在top10中，则需要删除用户地址
        if(isUserInTop10(userAddress)){
            // 如果头节点（存款最少）是用户地址，则需要将头节点更新为下一个节点
            if (top10Address[GUARD] == userAddress) {
                address _nextAddress = nextAddress(userAddress);
                top10Address[GUARD] = _nextAddress;
                top10Address[userAddress] = address(0);
                listSize--;

            // 如果用户存款最多(尾节点)
            }else if (top10Address[userAddress] == GUARD) {
                address _preAddress = preAddress(userAddress);
                top10Address[_preAddress] = GUARD;
                top10Address[userAddress] = address(0);
                listSize--;

                // 如果用户存款在中间，则上一个节点指向下一个节点，用户地址置空
            }else{
                address preAddress2 = preAddress(userAddress);
                address nextAddress2 = nextAddress(userAddress);
                top10Address[preAddress2] = nextAddress2;
                top10Address[userAddress] = address(0);
                listSize--;
            }
            // 获取用户地址金额刚好大于用户地址的节点
            // (address preAddress,address nextAddress) = getGreaterThanUserAddress(userAddress,top10Address[GUARD]);
            // 将用户地址插入到下个地址之前
            // top10Address[preAddress] = nextAddress;
        }
    }

    receive() external payable { 
        addressToSavePrice[msg.sender] += msg.value;
        if (isUserInTop10(msg.sender)) {
        updateTop10(msg.sender);  // 已在榜，更新排名
    } else {
        addToTop10(msg.sender);   // 不在榜，尝试加入
    }
        emit Received(msg.sender, msg.value);
    }

}


// 


