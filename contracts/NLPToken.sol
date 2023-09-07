// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract NLPToken is ERC20 {
    constructor(uint256 _amount) public ERC20("NLP Token", "NLP") {
        _mint(msg.sender, _amount);
    }
}