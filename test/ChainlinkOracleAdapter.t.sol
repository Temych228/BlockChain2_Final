// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ChainlinkOracleAdapter} from "../src/ChainlinkOracleAdapter.sol";
import {MockAggregator} from "./mocks/MockAggregator.sol";

contract ChainlinkOracleAdapterTest is Test {
    ChainlinkOracleAdapter adapter;
    MockAggregator mock;
    address admin = address(0xAD);

    function setUp() public {
        vm.warp(1_700_000_000);
        mock = new MockAggregator(8);
        adapter = new ChainlinkOracleAdapter(address(mock), 3600, admin);
    }

    function test_GetPrice_Success() public view {
        (uint256 price, uint256 updatedAt) = adapter.getPrice();
        assertEq(price, uint256(2000e8));
        assertEq(updatedAt, block.timestamp);
    }

    function test_GetPrice_Reverts_NegativePrice() public {
        mock.setPrice(-1);
        vm.expectRevert(abi.encodeWithSelector(ChainlinkOracleAdapter.NegativeOrZeroPrice.selector, int256(-1)));
        adapter.getPrice();
    }

    function test_GetPrice_Reverts_ZeroPrice() public {
        mock.setPrice(0);
        vm.expectRevert(abi.encodeWithSelector(ChainlinkOracleAdapter.NegativeOrZeroPrice.selector, int256(0)));
        adapter.getPrice();
    }

    function test_GetPrice_Reverts_StalePrice() public {
        mock.setUpdatedAt(block.timestamp - 7200);
        vm.expectRevert(
            abi.encodeWithSelector(
                ChainlinkOracleAdapter.StalePrice.selector, block.timestamp - 7200, block.timestamp, 3600
            )
        );
        adapter.getPrice();
    }

    function test_GetPrice_Reverts_IncompleteRound() public {
        mock.setRoundData(10, 9);
        vm.expectRevert(
            abi.encodeWithSelector(ChainlinkOracleAdapter.IncompleteRound.selector, uint80(10), uint80(9))
        );
        adapter.getPrice();
    }

    function test_SetMaxStaleness() public {
        vm.prank(admin);
        adapter.setMaxStaleness(7200);
        assertEq(adapter.maxStaleness(), 7200);
    }

    function test_SetMaxStaleness_RevertsForNonAdmin() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert();
        adapter.setMaxStaleness(7200);
    }

    function test_SetMaxStaleness_RevertsForZero() public {
        vm.prank(admin);
        vm.expectRevert(ChainlinkOracleAdapter.ZeroStaleness.selector);
        adapter.setMaxStaleness(0);
    }

    function test_GetPrice_ExactStalenessEdge() public {
        mock.setUpdatedAt(block.timestamp - 3600);
        (uint256 price,) = adapter.getPrice();
        assertGt(price, 0);
    }

    function test_GetPrice_JustPastStaleness() public {
        mock.setUpdatedAt(block.timestamp - 3601);
        vm.expectRevert();
        adapter.getPrice();
    }

    function testFuzz_StalenessEdge(uint256 age) public {
        age = bound(age, 0, 100_000);
        mock.setUpdatedAt(block.timestamp - age);

        if (age > 3600) {
            vm.expectRevert();
            adapter.getPrice();
        } else {
            (uint256 price,) = adapter.getPrice();
            assertGt(price, 0);
        }
    }
}
