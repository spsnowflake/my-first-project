// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";


contract UUPSProxyERC721 {
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    constructor(address _erc721V1,bytes memory _initData) {
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = _erc721V1;
        if (_initData.length > 0) {
            (bool success, ) = _erc721V1.delegatecall(_initData);
            require(success, "Delegate call failed");
        }
    }


    //  委托调用
    function _delegate(address _implementation) internal virtual {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }
    
    fallback() external payable {
        _delegate(_getImplementation());
    }

    
    receive() external payable {
        _delegate(_getImplementation());

    }


}













