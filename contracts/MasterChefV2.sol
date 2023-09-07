// SPDX-License-Identifier: MIT
import "./MasterChef.sol";

pragma solidity 0.6.12;

contract MasterChefV2 is MasterChef {
    uint256 public epochDuration = 30 days;
    
    uint256 public lastEpochNumber;
    uint256 public lastEpochStart;
    uint256 public lastEpochDeposit;
    
    uint256 public maxDepositAllowed;

    event Epoch(uint256 epochNumber, uint256 epochDeposit);
    event EpochDuration (uint256 oldDuration, uint256 newDuration);
    event MaxDepositAllowed (uint256 oldAllowed, uint256 newAllowed);

    constructor(
        NLPToken _esNLP,
        address _foundation,
        uint256 _esNLPPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) MasterChef(_esNLP, _foundation, _esNLPPerBlock, _startBlock, _bonusEndBlock) public {
        lastEpochStart = block.timestamp;
        maxDepositAllowed = 1000e18;
    }

    function setEpochDuration(uint256 newDuration) public onlyOwner {
        emit EpochDuration(epochDuration, newDuration);
        epochDuration = newDuration;
    }

    function setMaxDepositAllowed(uint256 newDepositAllowed) public onlyOwner {
        emit MaxDepositAllowed(maxDepositAllowed, newDepositAllowed);
        maxDepositAllowed = newDepositAllowed;
    }

    function resetEpoch() public {
        while (lastEpochStart + epochDuration <= block.timestamp) {
            emit Epoch(lastEpochNumber, lastEpochDeposit);
            lastEpochNumber += 1;
            lastEpochStart += epochDuration;
            lastEpochDeposit = 0;
        }
    }

    function getCurrentEpochDetails() public returns (uint256 epochNumber, uint256 epochStart, uint256 epochDeposit) {
        epochNumber = lastEpochNumber;
        epochStart = lastEpochStart;
        epochDeposit = lastEpochDeposit;
        while (epochStart + epochDuration <= block.timestamp) {
            epochNumber += 1;
            epochStart += epochDuration;
            epochDeposit = 0;
        } 
    }

    // Deposit LP tokens to MasterChef for esNLP allocation.
    function deposit(uint256 _pid, uint256 _amount) public override {
        resetEpoch();
        require(_amount + lastEpochDeposit <= maxDepositAllowed, "max depsoit limit exceeded");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accesNLPPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeesNLPTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender),address(this),_amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accesNLPPerShare).div(1e12);
        lastEpochDeposit += _amount;
        emit Deposit(msg.sender, _pid, _amount);
    }

}