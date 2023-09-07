// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IVester {

    function claimForAccount(address _account, address _receiver) external returns (uint256);

    function claimable(address _account) external view returns (uint256);
    function cumulativeClaimAmounts(address _account) external view returns (uint256);
    function claimedAmounts(address _account) external view returns (uint256);
    function getVestedAmount(address _account) external view returns (uint256);


}
