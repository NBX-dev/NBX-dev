// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./NLPToken.sol";

// MasterChef is the master of esNLP. He can make esNLP and he is a fair guy.

// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once esNLP is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of esNLP
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accesNLPPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accesNLPPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. esNLP to distribute per block.
        uint256 lastRewardBlock; // Last block number that esNLP distribution occurs.
        uint256 accesNLPPerShare; // Accumulated esNLP per share, times 1e12. See below.
    }
    // The esNLP TOKEN!
    NLPToken public esNLP;
    // Block number when bonus esNLP period ends.
    uint256 public bonusEndBlock;
    // esNLP tokens created per block.
    uint256 public esNLPPerBlock;
    // Bonus muliplier for early esNLP makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when esNLP mining starts.
    address public foundationWallet;
    uint256 public startBlock;
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        NLPToken _NLP,
        address _foundation,
        uint256 _NLPPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) public {
        esNLP = _NLP;
        foundationWallet = _foundation;
        esNLPPerBlock = _NLPPerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }
     function UpdateFoundationWallet(address _foundationWallet) external onlyOwner {
        foundationWallet = _foundationWallet;
    }
    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accesNLPPerShare: 0
            })
        );
    }

    // Update the given pool's esNLP allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }



    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return
                bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                    _to.sub(bonusEndBlock)
                );
        }
    }

    // View function to see pending esNLP on frontend.
    function pendingesNLP(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accesNLPPerShare = pool.accesNLPPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardBlock, block.number);
            uint256 esNLPReward =
                multiplier.mul(esNLPPerBlock).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accesNLPPerShare = accesNLPPerShare.add(
                esNLPReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accesNLPPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updateEmissionRate(uint256 _NLPPerBlock) public onlyOwner {
        massUpdatePools();
        esNLPPerBlock = _NLPPerBlock;
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 esNLPReward =
            multiplier.mul(esNLPPerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );
        pool.accesNLPPerShare = pool.accesNLPPerShare.add(
            esNLPReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for esNLP allocation.
    function deposit(uint256 _pid, uint256 _amount) public virtual {
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
        
        emit Deposit(msg.sender, _pid, _amount);
    }


     // Withdraw and Harvest LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending =
            user.amount.mul(pool.accesNLPPerShare).div(1e12).sub(
                user.rewardDebt
            );
        safeesNLPTransfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accesNLPPerShare).div(1e12);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
        emit Harvest(msg.sender, _pid, pending);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe esNLP transfer function, just in case if rounding error causes pool to not have enough esNLP.
    function safeesNLPTransfer(address _to, uint256 _amount) internal {
        uint256 esNLPBal = esNLP.allowance(foundationWallet, address(this));
        if (_amount > esNLPBal) {
          //  esNLP.transfer(_to, esNLPBal);
            esNLP.transferFrom(foundationWallet, _to, esNLPBal);
        } else {
           // esNLP.transfer(_to, _amount);
            esNLP.transferFrom(foundationWallet, _to, _amount);
        }
    }

   
}