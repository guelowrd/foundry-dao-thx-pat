// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Box} from "../src/Box.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {GovToken} from "../src/GovToken.sol";
import {MyGovernor} from "../src/MyGovernor.sol";

contract MyGovernorTest is Test {
    Box box;
    TimeLock timelock;
    GovToken govToken;
    MyGovernor myGovernor;

    address[] proposers;
    address[] executors;

    uint256[] values;
    bytes[] calldatas;
    address[] targets;

    address public USER = makeAddr("USER");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    uint256 public constant MIN_DELAY = 3600; // this is 1 hour
    uint256 public constant VOTING_DELAY = 1;
    uint256 public constant VOTING_PERIOD = 50400; // 1 week, this is how long voting lasts

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        vm.prank(USER);
        govToken.delegate(USER);
        timelock = new TimeLock(MIN_DELAY, proposers, executors);

        myGovernor = new MyGovernor(govToken, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(myGovernor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, msg.sender);

        box = new Box();
        box.transferOwnership(address(timelock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToStore = 777;
        string memory description = "Store 777 in Box";
        bytes memory encodedStoreFunction = abi.encodeWithSignature(
            "store(uint256)",
            valueToStore
        );
        values.push(0);
        calldatas.push(encodedStoreFunction);
        targets.push(address(box));

        // 1. Propose to the DAO
        uint256 proposalId = myGovernor.propose(
            targets,
            values,
            calldatas,
            description
        );

        // 2. View the state of the proposal (pending), warp time, and view the state again (active)
        console.log("Proposal State: ", uint256(myGovernor.state(proposalId)));
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);
        console.log("Proposal State: ", uint256(myGovernor.state(proposalId)));

        // 3. Vote
        string memory reason = "I don't dislike this proposal";
        uint8 voteWay = 1; // 0 = no, 1 = yes, 2 = abstain
        vm.prank(USER);
        myGovernor.castVoteWithReason(proposalId, voteWay, reason);
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 4. Queue the proposal
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        myGovernor.queue(targets, values, calldatas, descriptionHash);
        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // 5. Execute the proposal
        myGovernor.execute(targets, values, calldatas, descriptionHash);

        // 6. Verify that the box was updated
        assertEq(box.retrieve(), valueToStore);
        console.log("Box value: ", box.retrieve());
    }
}
