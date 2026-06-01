// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MyWallet { 
    string public name;
    mapping (address => bool) private approved;
    address public owner;

    modifier auth {
        address _owner;
        assembly {
            _owner := sload(owner.slot)
        }
        require (msg.sender == _owner, "Not authorized");
        _;
    }

    constructor(string memory  _name) {
        name = _name;
        // owner = msg.sender;
        assembly {
            sstore(owner.slot, caller())
        }
    } 

    function transferOwernship(address _addr) external auth {
        require(_addr!=address(0), "New owner is the zero address");

        address _owner;
        assembly {
            _owner := sload(owner.slot)
        }
        require(_owner != _addr, "New owner is the same as the old owner");
        // owner = _addr;
        assembly {
            sstore(owner.slot, _addr)
        }
    }
}