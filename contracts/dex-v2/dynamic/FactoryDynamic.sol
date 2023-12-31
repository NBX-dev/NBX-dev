// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../interfaces/IFactoryDynamic.sol';
import './PairDynamic.sol';

contract FactoryDynamic {
    address public feeTo;
    uint256 public protocolFeeFixed;
    uint256 public protocolFeeDynamic;

    mapping(address => mapping(address => mapping(bool => address))) public getPair;

    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, bool stable, address pair, uint, uint fee);
    event ProtocolFeeFixedChange(uint _protocolFeeFixed);
    event ProtocolFeeDynamicChange(uint _protocolFeeDynamic);
    event ProtocolFeeToChange(address _feeTo);

    constructor() {
      feeTo = msg.sender;
      protocolFeeFixed = 10; // min 0, max 1000 (0-10%)
      protocolFeeDynamic = 0; // min 0, max 1000, (0-100%)
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    // constant fee value
    function setProtocolFeeFixed(uint _protocolFeeFixed) external {
        require(msg.sender == feeTo, ': FORBIDDEN');

        // 1000 = 10%, bps
        if(_protocolFeeFixed > 1000)
          protocolFeeFixed = 1000;
        else
          protocolFeeFixed = _protocolFeeFixed;

        emit ProtocolFeeFixedChange(_protocolFeeFixed);
    }

    // % based fee value, bps
    function setProtocolFeeDynamic(uint _protocolFeeDynamic) external {
        require(msg.sender == feeTo, ': FORBIDDEN');

        if(_protocolFeeDynamic > 1000)
          protocolFeeDynamic = 1000;
        else
          protocolFeeDynamic = _protocolFeeDynamic;

        emit ProtocolFeeDynamicChange(_protocolFeeDynamic);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeTo, ': FORBIDDEN');
        require(_feeTo != address(0), ': Cannot set zero address');

        feeTo = _feeTo;

        emit ProtocolFeeToChange(_feeTo);
    }

    function createPair(address tokenA, address tokenB, uint feeType, bool stable) external returns (address pair) {
        require(tokenA != tokenB, ': IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), ': ZERO_ADDRESS');
        require(getPair[token0][token1][stable] == address(0), ': PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(PairDynamic).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, stable));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IPairDynamic(pair).initialize(token0, token1, feeType, stable);
        getPair[token0][token1][stable] = pair;
        getPair[token1][token0][stable] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, stable, pair, allPairs.length, feeType);
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(PairDynamic).creationCode);
    }
}
