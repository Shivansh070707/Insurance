// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Insurance.sol";
import "../src/mocks/stEth.sol";
import "../src/mocks/reward.sol";

contract CounterTest is Test {
    InsuranceVault public insurance;
    StETh public stETH;
    Reward public reward;

    function setUp() public {
        //deploying stEth
        stETH = new StETh();
        //deploying Reward Token
        reward = new Reward();
        //deploying Insurance
        insurance = new InsuranceVault(address(stETH), address(reward));
        reward.transferOwnership(address(insurance));
        //adding products
        insurance.addProduct("P1", 1, 1, 100);
        insurance.addProduct("P2", 2, 2, 200);
        insurance.addProduct("P3", 3, 3, 300);
        //buying products
        insurance.optInOutProduct{value: 100}(1, true);
    }

    function testdeposit(uint64 amount) public {
        //buying stEth by deposit eth
        stETH.submit{value: amount}(address(this));
        uint token = stETH.balanceOf(address(this));
        stETH.approve(address(insurance), token);
        insurance.deposit(1, token);
        uint userShares = insurance.userShares(address(this), 1);
        assertEq(userShares, token);
    }

    function testCalculateRewards(uint64 amount) public {
        stETH.submit{value: amount}(address(this));
        uint token = stETH.balanceOf(address(this));
        stETH.approve(address(insurance), token);
        insurance.deposit(1, token);
        insurance.calculateRewards(address(this));
    }

    function testCalculateRewardsAfterWithdraw(uint64 amount) public {
        vm.assume(amount > 0);
        stETH.submit{value: amount}(address(this));
        uint token = stETH.balanceOf(address(this));
        stETH.approve(address(insurance), token);
        insurance.deposit(1, token);
        insurance.withdraw(1, token);
        assertEq(insurance.calculateRewards(address(this)), 0);
    }

    function test_revert_withdraw() public {
        vm.expectRevert("Product does not exist");
        insurance.withdraw(10, 100);
    }

    function testWithdraw(uint64 amount) public {
        vm.assume(amount > 0);
        stETH.submit{value: amount}(address(this));
        uint token = stETH.balanceOf(address(this));
        stETH.approve(address(insurance), token);
        insurance.deposit(1, token);
        uint rewards = insurance.calculateRewards(address(this));
        insurance.withdraw(1, token);
        uint rewardToken = reward.balanceOf(address(this));
        assertEq(rewards, rewardToken);
    }
}
